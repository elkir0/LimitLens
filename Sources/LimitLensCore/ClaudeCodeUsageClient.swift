import Foundation

public protocol ClaudeUsageFetching {
    func fetchUsageSnapshot(oauthToken: String, now: Date) async throws -> CLIUsageSnapshot
}

public struct ClaudeCodeUsageClient: ClaudeUsageFetching {
    private let transport: HTTPTransport
    private let baseURL: URL

    public init(
        transport: HTTPTransport = URLSessionHTTPTransport(),
        baseURL: URL = URL(string: "https://api.anthropic.com")!
    ) {
        self.transport = transport
        self.baseURL = baseURL
    }

    public func fetchUsageSnapshot(oauthToken: String, now: Date = Date()) async throws -> CLIUsageSnapshot {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        components.path = "/api/oauth/usage"

        guard let url = components.url else {
            throw ProviderClientError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(oauthToken)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("LimitLens/1.0", forHTTPHeaderField: "User-Agent")

        let response: ClaudeCodeUsageResponse = try await decode(request)
        return response.snapshot(now: now)
    }

    private func decode<Response: Decodable>(_ request: URLRequest) async throws -> Response {
        do {
            let (data, response) = try await transport.data(for: request)
            try validate(response: response, data: data)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let string = try container.decode(String.self)
                if let date = fractionalISO8601Formatter.date(from: string) {
                    return date
                }
                if let date = standardISO8601Formatter.date(from: string) {
                    return date
                }
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Expected ISO8601 date"
                )
            }
            return try decoder.decode(Response.self, from: data)
        } catch let error as ProviderClientError {
            throw error
        } catch let error as DecodingError {
            throw ProviderClientError.decoding(error.readableDescription)
        } catch {
            throw ProviderClientError.network(error.localizedDescription)
        }
    }
}

private struct ClaudeCodeUsageResponse: Decodable {
    let fiveHour: UsageWindow?
    let sevenDay: UsageWindow?
    let sevenDaySonnet: UsageWindow?
    let extraUsage: ExtraUsage?

    private enum CodingKeys: String, CodingKey {
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
        case sevenDaySonnet = "seven_day_sonnet"
        case extraUsage = "extra_usage"
    }

    func snapshot(now: Date) -> CLIUsageSnapshot {
        var limits: [UsageLimitState] = []
        if let fiveHour {
            limits.append(fiveHour.limitState(
                id: "five_hour",
                label: "Session courante",
                detail: "Fenêtre 5h"
            ))
        }
        if let sevenDay {
            limits.append(sevenDay.limitState(
                id: "seven_day",
                label: "Semaine courante",
                detail: "Fenêtre 1 sem."
            ))
        }
        if let sevenDaySonnet {
            limits.append(sevenDaySonnet.limitState(
                id: "seven_day_sonnet",
                label: "Sonnet 7j",
                detail: "Sonnet uniquement"
            ))
        }
        if let extraLimit = extraUsage?.limitState() {
            limits.append(extraLimit)
        }

        var metrics: [UsageMetric] = []
        if let rateLimitTier = ProcessInfo.processInfo.environment["CLAUDE_CODE_RATE_LIMIT_TIER"], !rateLimitTier.isEmpty {
            metrics.append(UsageMetric(id: "tier", title: "Palier", value: rateLimitTier))
        } else {
            metrics.append(UsageMetric(id: "subscription", title: "Abonnement", value: "Max"))
        }

        return CLIUsageSnapshot(
            source: .claudeCode,
            health: usageHealth(for: limits),
            summary: "Exact /usage",
            limits: limits,
            metrics: metrics,
            lastUpdated: now,
            note: "Lu depuis le endpoint OAuth Claude Code."
        )
    }
}

private struct UsageWindow: Decodable {
    let utilization: Double
    let resetsAt: Date?

    private enum CodingKeys: String, CodingKey {
        case utilization
        case resetsAt = "resets_at"
    }

    func limitState(id: String, label: String, detail: String) -> UsageLimitState {
        UsageLimitState(
            id: id,
            label: label,
            usedPercent: utilization,
            resetDate: resetsAt,
            detail: detail
        )
    }
}

private struct ExtraUsage: Decodable {
    let isEnabled: Bool
    let monthlyLimit: Double?
    let usedCredits: Double?
    let utilization: Double?
    let currency: String?

    private enum CodingKeys: String, CodingKey {
        case isEnabled = "is_enabled"
        case monthlyLimit = "monthly_limit"
        case usedCredits = "used_credits"
        case utilization
        case currency
    }

    func limitState() -> UsageLimitState? {
        guard isEnabled, let usedCredits, let monthlyLimit else {
            return nil
        }

        let used = MetricFormatter.currencyUSD(dollars(fromCents: usedCredits))
        let limit = MetricFormatter.currencyUSD(dollars(fromCents: monthlyLimit))
        return UsageLimitState(
            id: "extra_usage",
            label: "Extra usage",
            usedPercent: utilization,
            resetDate: nil,
            detail: "\(used) / \(limit)"
        )
    }
}

private func dollars(fromCents cents: Double) -> Decimal {
    Decimal(cents / 100)
}

private func validate(response: HTTPURLResponse, data: Data) throws {
    guard !(200..<300).contains(response.statusCode) else {
        return
    }

    switch response.statusCode {
    case 401:
        throw ProviderClientError.unauthorized
    case 403:
        throw ProviderClientError.forbidden
    case 429:
        let retryAfter = response.value(forHTTPHeaderField: "retry-after")
        throw ProviderClientError.rateLimited(retryAfter: retryAfter)
    default:
        let body = String(data: data, encoding: .utf8) ?? ""
        throw ProviderClientError.unexpectedStatus(response.statusCode, String(body.prefix(240)))
    }
}

private func usageHealth(for limits: [UsageLimitState]) -> CLIUsageHealth {
    let maxPercent = limits.compactMap(\.usedPercent).max() ?? 0
    if maxPercent >= 95 {
        return .error
    }
    if maxPercent >= 75 {
        return .warning
    }
    return .ok
}

private let standardISO8601Formatter = ISO8601DateFormatter()

private let fractionalISO8601Formatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
}()

private extension DecodingError {
    var readableDescription: String {
        switch self {
        case .typeMismatch(_, let context),
             .valueNotFound(_, let context),
             .keyNotFound(_, let context),
             .dataCorrupted(let context):
            return context.debugDescription
        @unknown default:
            return localizedDescription
        }
    }
}
