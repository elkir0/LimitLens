import Foundation

public enum CodexUsageParser {
    public static func parse(lines: [String]) -> CLIUsageSnapshot? {
        var latestByBucket: [String: CodexRateLimitBucket] = [:]

        for line in lines {
            guard
                let object = jsonObject(from: line),
                let timestamp = date(from: object["timestamp"] as? String),
                let payload = object["payload"] as? [String: Any],
                payload["type"] as? String == "token_count",
                let rateLimits = (payload["rate_limits"] as? [String: Any])
                    ?? (object["rate_limits"] as? [String: Any])
            else {
                continue
            }

            var limits: [UsageLimitState] = []
            if let primary = rateLimits["primary"] as? [String: Any] {
                limits.append(limitState(id: "primary", label: "Session courante", object: primary))
            }
            if let secondary = rateLimits["secondary"] as? [String: Any] {
                limits.append(limitState(id: "secondary", label: "Semaine courante", object: secondary))
            }

            var metrics: [UsageMetric] = []
            if
                let credits = rateLimits["credits"] as? [String: Any],
                let balance = credits["balance"] as? [String: Any],
                let used = decimal(balance["used"]),
                let limit = decimal(balance["limit"])
            {
                metrics.append(UsageMetric(
                    id: "credits",
                    title: "Extra",
                    value: "\(MetricFormatter.currencyUSD(used)) / \(MetricFormatter.currencyUSD(limit))"
                ))
            } else if let credits = rateLimits["credits"] as? [String: Any] {
                let hasCredits = credits["has_credits"] as? Bool ?? false
                let unlimited = credits["unlimited"] as? Bool ?? false
                metrics.append(UsageMetric(
                    id: "credits",
                    title: "Extra",
                    value: unlimited ? "Illimité" : (hasCredits ? "Disponible" : "Aucun")
                ))
            }

            let bucketID = (rateLimits["limit_id"] as? String) ?? "default"
            let bucket = CodexRateLimitBucket(
                id: bucketID,
                timestamp: timestamp,
                limits: limits,
                metrics: metrics
            )

            if
                let current = latestByBucket[bucketID],
                current.timestamp >= timestamp
            {
                continue
            }

            latestByBucket[bucketID] = bucket
        }

        guard !latestByBucket.isEmpty else {
            return nil
        }

        let buckets = Array(latestByBucket.values)
        let newestTimestamp = buckets.map(\.timestamp).max() ?? Date()
        let limits = mergedLimits(
            from: buckets,
            referenceDate: newestTimestamp,
            discardExpired: buckets.count > 1
        )
        let metrics = buckets
            .sorted { $0.timestamp > $1.timestamp }
            .first { !$0.metrics.isEmpty }?
            .metrics ?? []

        return CLIUsageSnapshot(
            source: .codex,
            health: health(for: limits),
            summary: "Local /status",
            limits: limits,
            metrics: metrics,
            lastUpdated: newestTimestamp,
            note: "Lu depuis les événements locaux ~/.codex."
        )
    }

    private static func limitState(id: String, label: String, object: [String: Any]) -> UsageLimitState {
        let usedPercent = double(object["used_percent"])
        let resetDate = (object["resets_at"] as? TimeInterval).map { Date(timeIntervalSince1970: $0) }
        let minutes = int(object["window_minutes"])
        let detail = minutes.map { windowDescription(minutes: $0) } ?? "Limite Codex locale"
        return UsageLimitState(id: id, label: label, usedPercent: usedPercent, resetDate: resetDate, detail: detail)
    }

    private static func mergedLimits(
        from buckets: [CodexRateLimitBucket],
        referenceDate: Date,
        discardExpired: Bool
    ) -> [UsageLimitState] {
        var merged: [String: UsageLimitState] = [:]

        for bucket in buckets {
            for limit in bucket.limits where !discardExpired || isActive(limit, at: referenceDate) {
                merged[limit.id] = moreConstrained(current: merged[limit.id], candidate: limit)
            }
        }

        let orderedIDs = ["primary", "secondary"]
        var ordered = orderedIDs.compactMap { merged.removeValue(forKey: $0) }
        ordered.append(contentsOf: merged.values.sorted { $0.label < $1.label })
        return ordered
    }

    private static func isActive(_ limit: UsageLimitState, at referenceDate: Date) -> Bool {
        guard let resetDate = limit.resetDate else {
            return true
        }
        return resetDate > referenceDate
    }

    private static func moreConstrained(
        current: UsageLimitState?,
        candidate: UsageLimitState
    ) -> UsageLimitState {
        guard let current else {
            return candidate
        }

        switch (current.usedPercent, candidate.usedPercent) {
        case let (currentPercent?, candidatePercent?):
            if candidatePercent != currentPercent {
                return candidatePercent > currentPercent ? candidate : current
            }
        case (nil, _?):
            return candidate
        case (_?, nil):
            return current
        case (nil, nil):
            break
        }

        switch (current.resetDate, candidate.resetDate) {
        case let (currentDate?, candidateDate?):
            return candidateDate < currentDate ? candidate : current
        case (nil, _?):
            return candidate
        default:
            return current
        }
    }

    private struct CodexRateLimitBucket {
        let id: String
        let timestamp: Date
        let limits: [UsageLimitState]
        let metrics: [UsageMetric]
    }
}

public enum ClaudeUsageParser {
    public static func parse(lines: [String], now: Date = Date()) -> CLIUsageSnapshot? {
        let entries = lines.compactMap(ClaudeUsageEntry.init(line:))
        guard !entries.isEmpty else {
            return nil
        }

        let fiveHoursAgo = now.addingTimeInterval(-5 * 60 * 60)
        let sevenDaysAgo = now.addingTimeInterval(-7 * 24 * 60 * 60)
        let fiveHourEntries = entries.filter { $0.timestamp >= fiveHoursAgo && $0.timestamp <= now }
        let sevenDayEntries = entries.filter { $0.timestamp >= sevenDaysAgo && $0.timestamp <= now }
        let sonnetEntries = sevenDayEntries.filter { $0.model.localizedCaseInsensitiveContains("sonnet") }
        let latest = entries.max { $0.timestamp < $1.timestamp }

        let fiveHourTokens = fiveHourEntries.reduce(0) { $0 + $1.totalTokens }
        let sevenDayTokens = sevenDayEntries.reduce(0) { $0 + $1.totalTokens }
        let sonnetTokens = sonnetEntries.reduce(0) { $0 + $1.totalTokens }

        let resetDate = fiveHourEntries.map(\.timestamp).min()?.addingTimeInterval(5 * 60 * 60)
        let weekResetDate = sevenDayEntries.map(\.timestamp).min()?.addingTimeInterval(7 * 24 * 60 * 60)

        var modelTotals: [String: Int] = [:]
        for entry in sevenDayEntries {
            modelTotals[entry.model, default: 0] += entry.totalTokens
        }
        let topModel = modelTotals.max { $0.value < $1.value }

        let limits = [
            UsageLimitState(
                id: "5h",
                label: "Fenêtre 5h",
                usedPercent: nil,
                resetDate: resetDate,
                detail: "Tokens locaux uniquement"
            ),
            UsageLimitState(
                id: "7d",
                label: "Semaine courante",
                usedPercent: nil,
                resetDate: weekResetDate,
                detail: "Tokens locaux uniquement"
            )
        ]

        var metrics = [
            UsageMetric(id: "5h", title: "5h local", value: MetricFormatter.tokens(fiveHourTokens)),
            UsageMetric(id: "7d", title: "7j local", value: MetricFormatter.tokens(sevenDayTokens)),
            UsageMetric(id: "sonnet7d", title: "Sonnet 7d", value: MetricFormatter.tokens(sonnetTokens))
        ]
        if let topModel {
            metrics.append(UsageMetric(id: "topModel", title: "Modèle top", value: shortModelName(topModel.key)))
        }

        return CLIUsageSnapshot(
            source: .claudeCode,
            health: .warning,
            summary: "Estimation locale",
            limits: limits,
            metrics: metrics,
            lastUpdated: latest?.timestamp,
            note: "Les pourcentages exacts de /usage ne sont pas exposés hors interface interactive Claude Code."
        )
    }
}

public protocol UsageReading {
    func readCodex() async -> CLIUsageSnapshot
    func readClaudeExact(now: Date) async throws -> CLIUsageSnapshot
    func readLocalClaude(now: Date) async -> CLIUsageSnapshot?
}

public struct LocalUsageReader: UsageReading {
    private let homeDirectory: URL
    private let providerFolders: [CLIUsageSource: URL]
    private let claudeOAuthStore: ClaudeOAuthStore
    private let claudeUsageFetcher: ClaudeUsageFetching

    public init(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        providerFolders: [CLIUsageSource: URL] = [:],
        claudeOAuthStore: ClaudeOAuthStore = ClaudeCodeKeychainOAuthStore(),
        claudeUsageFetcher: ClaudeUsageFetching = ClaudeCodeUsageClient()
    ) {
        self.homeDirectory = homeDirectory
        self.providerFolders = providerFolders
        self.claudeOAuthStore = claudeOAuthStore
        self.claudeUsageFetcher = claudeUsageFetcher
    }

    /// Scans the local Codex session logs off the calling actor so the heavy
    /// file I/O and JSON parsing never block the UI thread.
    public func readCodex() async -> CLIUsageSnapshot {
        guard let root = providerFolders[.codex] else {
            return .unavailable(
                source: .codex,
                note: "Dossier Codex non configuré. Choisissez ~/.codex/sessions dans les réglages."
            )
        }
        return await Task.detached(priority: .utility) {
            let scan = recentJSONLScan(root: root, fileLimit: 300) { line in
                line.contains("\"token_count\"") || line.contains("\"rate_limits\"")
            }
            return CodexUsageParser.parse(lines: scan.lines) ?? .unavailable(
                source: .codex,
                note: "Aucun événement Codex token_count avec rate_limits trouvé dans ~/.codex/sessions. \(scan.summary)"
            )
        }.value
    }

    public func readClaude(now: Date = Date()) async -> CLIUsageSnapshot {
        do {
            let exactSnapshot = try await readClaudeExact(now: now)
            if exactSnapshot.limits.isEmpty, let localSnapshot = await readLocalClaude(now: now) {
                return localSnapshot
            }
            return exactSnapshot
        } catch ProviderClientError.missingKey {
            return await readLocalClaude(now: now) ?? .unavailable(
                source: .claudeCode,
                note: "Token OAuth Claude Code introuvable dans le Keychain macOS."
            )
        } catch ProviderClientError.unauthorized {
            return await readLocalClaude(now: now) ?? .unavailable(
                source: .claudeCode,
                note: "Token OAuth Claude Code expiré ou refusé. Ouvrez Claude Code pour rafraîchir la connexion."
            )
        } catch ProviderClientError.rateLimited(let retryAfter) {
            let suffix = retryAfter.map { " Réessayez après \($0)." } ?? ""
            return await readLocalClaude(now: now) ?? .unavailable(
                source: .claudeCode,
                note: "Endpoint /usage Claude Code temporairement limité.\(suffix)"
            )
        } catch {
            return await readLocalClaude(now: now) ?? .unavailable(
                source: .claudeCode,
                note: "Lecture exacte Claude Code impossible: \(error.localizedDescription)"
            )
        }
    }

    public func readClaudeExact(now: Date = Date()) async throws -> CLIUsageSnapshot {
        guard let token = try await claudeOAuthStore.readAccessToken() else {
            throw ProviderClientError.missingKey
        }

        return try await claudeUsageFetcher.fetchUsageSnapshot(oauthToken: token, now: now)
    }

    public func readLocalClaude(now: Date) async -> CLIUsageSnapshot? {
        guard let root = providerFolders[.claudeCode] else {
            return nil
        }
        return await Task.detached(priority: .utility) {
            let scan = recentJSONLScan(root: root, fileLimit: 300) { line in
                line.contains("\"type\":\"assistant\"") && line.contains("\"usage\"")
            }
            return ClaudeUsageParser.parse(lines: scan.lines, now: now)
        }.value
    }

}

private func recentJSONLScan(root: URL, fileLimit: Int, lineFilter: (String) -> Bool) -> JSONLScan {
    let fileManager = FileManager.default
    guard let enumerator = fileManager.enumerator(
        at: root,
        includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
        options: [.skipsHiddenFiles]
    ) else {
        return JSONLScan(lines: [], fileCount: 0, readableFileCount: 0, lineCount: 0)
    }

    var files: [(url: URL, modified: Date)] = []
    for case let url as URL in enumerator where url.pathExtension == "jsonl" {
        guard
            let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .isRegularFileKey]),
            values.isRegularFile == true
        else {
            continue
        }
        files.append((url, values.contentModificationDate ?? .distantPast))
    }

    let selectedFiles = files
        .sorted { $0.modified > $1.modified }
        .prefix(fileLimit)
    var readableFileCount = 0
    var lines: [String] = []

    for file in selectedFiles {
        guard let content = try? String(contentsOf: file.url, encoding: .utf8) else {
            continue
        }
        readableFileCount += 1
        lines.append(contentsOf: content
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map(String.init)
            .filter(lineFilter))
    }

    return JSONLScan(
        lines: lines,
        fileCount: selectedFiles.count,
        readableFileCount: readableFileCount,
        lineCount: lines.count
    )
}

private struct JSONLScan {
    let lines: [String]
    let fileCount: Int
    let readableFileCount: Int
    let lineCount: Int

    var summary: String {
        "\(fileDescription(fileCount)), \(readableFileCount) lisibles, \(lineDescription(lineCount)) candidates."
    }

    private func fileDescription(_ count: Int) -> String {
        count == 1 ? "1 fichier" : "\(count) fichiers"
    }

    private func lineDescription(_ count: Int) -> String {
        count == 1 ? "1 ligne" : "\(count) lignes"
    }
}

private struct ClaudeUsageEntry {
    let timestamp: Date
    let model: String
    let totalTokens: Int

    init?(line: String) {
        guard
            let object = jsonObject(from: line),
            object["type"] as? String == "assistant",
            let timestamp = date(from: object["timestamp"] as? String),
            let message = object["message"] as? [String: Any],
            let model = message["model"] as? String,
            model != "<synthetic>",
            let usage = message["usage"] as? [String: Any]
        else {
            return nil
        }

        self.timestamp = timestamp
        self.model = model
        self.totalTokens = (int(usage["input_tokens"]) ?? 0)
            + (int(usage["output_tokens"]) ?? 0)
            + (int(usage["cache_read_input_tokens"]) ?? 0)
            + (int(usage["cache_creation_input_tokens"]) ?? 0)
    }
}

private func jsonObject(from line: String) -> [String: Any]? {
    guard let data = line.data(using: .utf8) else {
        return nil
    }
    return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
}

private func date(from string: String?) -> Date? {
    guard let string else {
        return nil
    }
    if let date = fractionalISO8601Formatter.date(from: string) {
        return date
    }
    return standardISO8601Formatter.date(from: string)
}

private let standardISO8601Formatter = ISO8601DateFormatter()

private let fractionalISO8601Formatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
}()

private func int(_ value: Any?) -> Int? {
    if let int = value as? Int {
        return int
    }
    if let double = value as? Double {
        return Int(double)
    }
    if let number = value as? NSNumber {
        return number.intValue
    }
    return nil
}

private func double(_ value: Any?) -> Double? {
    if let double = value as? Double {
        return double
    }
    if let int = value as? Int {
        return Double(int)
    }
    if let number = value as? NSNumber {
        return number.doubleValue
    }
    return nil
}

private func decimal(_ value: Any?) -> Decimal? {
    if let double = double(value) {
        return Decimal(double)
    }
    if let string = value as? String {
        return Decimal(string: string)
    }
    return nil
}

private func health(for limits: [UsageLimitState]) -> CLIUsageHealth {
    let maxPercent = limits.compactMap(\.usedPercent).max() ?? 0
    if maxPercent >= 95 {
        return .error
    }
    if maxPercent >= 75 {
        return .warning
    }
    return .ok
}

private func windowDescription(minutes: Int) -> String {
    if minutes % 10_080 == 0 {
        return "Fenêtre \(minutes / 10_080) sem."
    }
    if minutes % 60 == 0 {
        return "Fenêtre \(minutes / 60)h"
    }
    return "Fenêtre \(minutes)m"
}

private func shortModelName(_ model: String) -> String {
    model
        .replacingOccurrences(of: "claude-", with: "")
        .replacingOccurrences(of: "-20251101", with: "")
        .replacingOccurrences(of: "-20250929", with: "")
}
