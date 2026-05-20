import Combine
import Foundation

@MainActor
public final class LocalUsageStore: ObservableObject {
    @Published public private(set) var snapshots: [CLIUsageSnapshot]
    @Published public private(set) var isRefreshing = false
    @Published public private(set) var lastRefresh: Date?
    @Published public var refreshInterval: RefreshInterval {
        didSet {
            userDefaults.set(refreshInterval.rawValue, forKey: RefreshInterval.userDefaultsKey)
        }
    }

    private let reader: any UsageReading
    public let configuration: ProviderConfiguration
    private let userDefaults: UserDefaults
    private var autoRefreshStarted = false
    private var cachedClaudeExact: CLIUsageSnapshot?
    private var claudeBackoffUntil: Date?

    private enum CacheKey {
        static let claudeExactSnapshot = "LimitLens.claudeExactSnapshot"
        static let claudeBackoffUntil = "LimitLens.claudeBackoffUntil"
    }

    public init(
        reader: any UsageReading = LocalUsageReader(),
        configuration: ProviderConfiguration = .defaultEnabled,
        userDefaults: UserDefaults = .standard
    ) {
        self.reader = reader
        self.configuration = configuration
        self.userDefaults = userDefaults
        self.refreshInterval = RefreshInterval.resolved(
            rawValue: userDefaults.integer(forKey: RefreshInterval.userDefaultsKey)
        )
        self.cachedClaudeExact = Self.readCachedClaudeExact(from: userDefaults)
        let backoffTimestamp = userDefaults.double(forKey: CacheKey.claudeBackoffUntil)
        self.claudeBackoffUntil = backoffTimestamp > 0 ? Date(timeIntervalSince1970: backoffTimestamp) : nil
        self.snapshots = configuration.activeSources.map {
            .unavailable(source: $0, note: "En attente de la première lecture locale.")
        }
    }

    public func snapshot(for source: CLIUsageSource) -> CLIUsageSnapshot {
        if configuration.setupState(for: source) == .disabled {
            return .unavailable(source: source, note: "Fournisseur désactivé.")
        }
        return snapshots.first { $0.source == source } ?? .unavailable(source: source, note: "Aucun instantané chargé.")
    }

    public func refresh(now: Date = Date()) async {
        isRefreshing = true
        defer { isRefreshing = false }

        var refreshedSnapshots: [CLIUsageSnapshot] = []
        for source in configuration.activeSources {
            switch source {
            case .claudeCode:
                refreshedSnapshots.append(await readStableClaude(now: now))
            case .codex:
                refreshedSnapshots.append(await reader.readCodex())
            }
        }
        lastRefresh = now
        snapshots = refreshedSnapshots
    }

    private func readStableClaude(now: Date) async -> CLIUsageSnapshot {
        if let claudeBackoffUntil, claudeBackoffUntil > now, let cachedClaudeExact {
            return cachedClaude(cachedClaudeExact, reason: "Endpoint /usage Claude Code temporairement limité; dernier quota exact conservé.")
        }

        do {
            let exact = try await reader.readClaudeExact(now: now)
            if exact.hasUtilizationPercent {
                cacheClaudeExact(exact)
            }
            claudeBackoffUntil = nil
            userDefaults.removeObject(forKey: CacheKey.claudeBackoffUntil)

            if exact.hasUtilizationPercent || cachedClaudeExact == nil {
                return exact
            }

            return cachedClaude(
                cachedClaudeExact!,
                reason: "Endpoint /usage Claude Code sans pourcentage exploitable; dernier quota exact conservé."
            )
        } catch ProviderClientError.rateLimited(let retryAfter) {
            let backoffUntil = Self.rateLimitBackoffDate(retryAfter: retryAfter, now: now)
            claudeBackoffUntil = backoffUntil
            userDefaults.set(backoffUntil.timeIntervalSince1970, forKey: CacheKey.claudeBackoffUntil)
            if let cachedClaudeExact {
                return cachedClaude(
                    cachedClaudeExact,
                    reason: "Endpoint /usage Claude Code temporairement limité; dernier quota exact conservé."
                )
            }
            return .unavailable(
                source: .claudeCode,
                note: "Endpoint /usage Claude Code temporairement limité. Aucune donnée exacte en cache."
            )
        } catch ProviderClientError.missingKey {
            if let cachedClaudeExact {
                return cachedClaude(
                    cachedClaudeExact,
                    reason: "Token OAuth Claude Code introuvable; dernier quota exact conservé."
                )
            }
            return await reader.readLocalClaude(now: now) ?? .unavailable(
                source: .claudeCode,
                note: "Token OAuth Claude Code introuvable dans le Keychain macOS."
            )
        } catch ProviderClientError.unauthorized {
            if let cachedClaudeExact {
                return cachedClaude(
                    cachedClaudeExact,
                    reason: "Token OAuth Claude Code refusé; dernier quota exact conservé."
                )
            }
            return await reader.readLocalClaude(now: now) ?? .unavailable(
                source: .claudeCode,
                note: "Token OAuth Claude Code expiré ou refusé. Ouvrez Claude Code pour rafraîchir la connexion."
            )
        } catch {
            if let cachedClaudeExact {
                return cachedClaude(
                    cachedClaudeExact,
                    reason: "Lecture exacte Claude Code impossible; dernier quota exact conservé."
                )
            }
            return await reader.readLocalClaude(now: now) ?? .unavailable(
                source: .claudeCode,
                note: "Lecture exacte Claude Code impossible: \(error.localizedDescription)"
            )
        }
    }

    private func cacheClaudeExact(_ snapshot: CLIUsageSnapshot) {
        cachedClaudeExact = snapshot
        guard let data = try? JSONEncoder().encode(snapshot) else {
            return
        }
        userDefaults.set(data, forKey: CacheKey.claudeExactSnapshot)
    }

    private func cachedClaude(_ snapshot: CLIUsageSnapshot, reason: String) -> CLIUsageSnapshot {
        CLIUsageSnapshot(
            source: snapshot.source,
            health: snapshot.health,
            summary: "Exact /usage (cache)",
            limits: snapshot.limits,
            metrics: snapshot.metrics,
            lastUpdated: snapshot.lastUpdated,
            note: reason
        )
    }

    private static func readCachedClaudeExact(from userDefaults: UserDefaults) -> CLIUsageSnapshot? {
        guard let data = userDefaults.data(forKey: CacheKey.claudeExactSnapshot) else {
            return nil
        }
        return try? JSONDecoder().decode(CLIUsageSnapshot.self, from: data)
    }

    private static func rateLimitBackoffDate(retryAfter: String?, now: Date) -> Date {
        guard let retryAfter else {
            return now.addingTimeInterval(15 * 60)
        }

        if let seconds = TimeInterval(retryAfter.trimmingCharacters(in: .whitespacesAndNewlines)) {
            return now.addingTimeInterval(max(seconds, 60))
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE',' dd MMM yyyy HH':'mm':'ss z"
        return formatter.date(from: retryAfter) ?? now.addingTimeInterval(15 * 60)
    }

    /// Starts the periodic refresh loop. Safe to call repeatedly; only the first
    /// call has an effect. The loop re-reads `refreshInterval` each tick, so a
    /// settings change takes effect on the next tick without restarting the loop
    /// or forcing an immediate refresh.
    ///
    /// The first-call guard means a cancelled loop is not restarted, so this is
    /// meant to be driven by an app-lifetime-stable owner (the `MenuBarExtra`
    /// label), whose `task` is never cancelled before the app quits.
    public func startAutoRefresh() async {
        guard !autoRefreshStarted else { return }
        autoRefreshStarted = true

        await refresh()
        while !Task.isCancelled {
            do {
                try await Task.sleep(nanoseconds: UInt64(refreshInterval.seconds * 1_000_000_000))
            } catch {
                break
            }
            guard !Task.isCancelled else {
                break
            }
            await refresh()
        }
    }
}

private extension CLIUsageSnapshot {
    var hasUtilizationPercent: Bool {
        limits.contains { $0.usedPercent != nil }
    }
}
