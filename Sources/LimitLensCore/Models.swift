import Foundation

public enum Provider: String, CaseIterable, Identifiable, Sendable {
    case openAI = "OpenAI"
    case anthropic = "Anthropic"

    public var id: String { rawValue }
}

public enum ProviderHealth: String, Equatable, Sendable {
    case ok
    case warning
    case error
    case unconfigured

    public var severity: Int {
        switch self {
        case .ok: 0
        case .unconfigured: 1
        case .warning: 2
        case .error: 3
        }
    }
}

public struct UsageMetric: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let value: String
    public let detail: String?

    public init(id: String, title: String, value: String, detail: String? = nil) {
        self.id = id
        self.title = title
        self.value = value
        self.detail = detail
    }
}

public struct LimitMetric: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let value: String
    public let detail: String?

    public init(id: String, title: String, value: String, detail: String? = nil) {
        self.id = id
        self.title = title
        self.value = value
        self.detail = detail
    }
}

public struct ProviderSnapshot: Equatable, Identifiable, Sendable {
    public var id: Provider { provider }
    public let provider: Provider
    public let health: ProviderHealth
    public let summary: String
    public let costUSD: Decimal?
    public let totalTokens: Int?
    public let requestCount: Int?
    public let usageMetrics: [UsageMetric]
    public let limits: [LimitMetric]
    public let lastUpdated: Date?
    public let errorMessage: String?

    public init(
        provider: Provider,
        health: ProviderHealth,
        summary: String,
        costUSD: Decimal?,
        totalTokens: Int?,
        requestCount: Int?,
        usageMetrics: [UsageMetric],
        limits: [LimitMetric],
        lastUpdated: Date?,
        errorMessage: String?
    ) {
        self.provider = provider
        self.health = health
        self.summary = summary
        self.costUSD = costUSD
        self.totalTokens = totalTokens
        self.requestCount = requestCount
        self.usageMetrics = usageMetrics
        self.limits = limits
        self.lastUpdated = lastUpdated
        self.errorMessage = errorMessage
    }
}

public enum ProviderClientError: Error, Equatable, Sendable {
    case missingKey
    case unauthorized
    case forbidden
    case rateLimited(retryAfter: String?)
    case network(String)
    case unexpectedStatus(Int, String)
    case decoding(String)
    case invalidResponse
    case missingProjectID
}
