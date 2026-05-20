import Foundation

public enum StatusEvaluator {
    public static func snapshot(
        provider: Provider,
        credentialsPresent: Bool,
        costUSD: Decimal?,
        totalTokens: Int?,
        requestCount: Int?,
        limits: [LimitMetric],
        error: ProviderClientError?,
        now: Date
    ) -> ProviderSnapshot {
        guard credentialsPresent else {
            return ProviderSnapshot(
                provider: provider,
                health: .unconfigured,
                summary: "Key missing",
                costUSD: nil,
                totalTokens: nil,
                requestCount: nil,
                usageMetrics: [],
                limits: [],
                lastUpdated: nil,
                errorMessage: "Add an API admin key in settings."
            )
        }

        if let error {
            return ProviderSnapshot(
                provider: provider,
                health: health(for: error),
                summary: summary(for: error),
                costUSD: costUSD,
                totalTokens: totalTokens,
                requestCount: requestCount,
                usageMetrics: usageMetrics(costUSD: costUSD, totalTokens: totalTokens, requestCount: requestCount),
                limits: limits,
                lastUpdated: nil,
                errorMessage: detail(for: error)
            )
        }

        let hasData = costUSD != nil || totalTokens != nil || requestCount != nil || !limits.isEmpty
        return ProviderSnapshot(
            provider: provider,
            health: hasData ? .ok : .warning,
            summary: hasData ? "Connected" : "No usage data",
            costUSD: costUSD,
            totalTokens: totalTokens,
            requestCount: requestCount,
            usageMetrics: usageMetrics(costUSD: costUSD, totalTokens: totalTokens, requestCount: requestCount),
            limits: limits,
            lastUpdated: now,
            errorMessage: hasData ? nil : "The API responded, but no usage or limit data was available."
        )
    }

    private static func health(for error: ProviderClientError) -> ProviderHealth {
        switch error {
        case .unauthorized, .missingKey:
            return .error
        case .forbidden, .rateLimited, .network, .unexpectedStatus, .decoding, .invalidResponse, .missingProjectID:
            return .warning
        }
    }

    private static func summary(for error: ProviderClientError) -> String {
        switch error {
        case .missingKey:
            return "Key missing"
        case .unauthorized:
            return "Invalid key"
        case .forbidden:
            return "Permission needed"
        case .rateLimited:
            return "Rate limited"
        case .network:
            return "Network issue"
        case .unexpectedStatus:
            return "API error"
        case .decoding, .invalidResponse:
            return "Data unreadable"
        case .missingProjectID:
            return "Project ID missing"
        }
    }

    private static func detail(for error: ProviderClientError) -> String {
        switch error {
        case .missingKey:
            return "Add an API admin key in settings."
        case .unauthorized:
            return "The configured key was rejected by the provider."
        case .forbidden:
            return "The key works, but this endpoint requires admin or organization permissions."
        case .rateLimited(let retryAfter):
            if let retryAfter, !retryAfter.isEmpty {
                return "The provider asked to retry after \(retryAfter)."
            }
            return "The provider rate limited this dashboard request."
        case .network(let message):
            return message
        case .unexpectedStatus(let status, let body):
            return body.isEmpty ? "HTTP \(status)" : "HTTP \(status): \(body)"
        case .decoding(let message):
            return message
        case .invalidResponse:
            return "The provider response was not valid HTTP."
        case .missingProjectID:
            return "OpenAI project rate limits require a project ID."
        }
    }

    private static func usageMetrics(
        costUSD: Decimal?,
        totalTokens: Int?,
        requestCount: Int?
    ) -> [UsageMetric] {
        var metrics: [UsageMetric] = []

        if let costUSD {
            metrics.append(UsageMetric(id: "cost", title: "Cost", value: MetricFormatter.currencyUSD(costUSD)))
        }
        if let totalTokens {
            metrics.append(UsageMetric(id: "tokens", title: "Tokens", value: MetricFormatter.tokens(totalTokens)))
        }
        if let requestCount {
            metrics.append(UsageMetric(id: "requests", title: "Requests", value: MetricFormatter.compactInteger(requestCount)))
        }

        return metrics
    }
}
