import Foundation

public protocol HTTPTransport {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

public struct URLSessionHTTPTransport: HTTPTransport {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ProviderClientError.invalidResponse
        }
        return (data, httpResponse)
    }
}

public struct OpenAIConfiguration: Equatable, Sendable {
    public let adminKey: String
    public let projectID: String?

    public init(adminKey: String, projectID: String?) {
        self.adminKey = adminKey
        self.projectID = projectID?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    }
}

public struct AnthropicConfiguration: Equatable, Sendable {
    public let adminKey: String

    public init(adminKey: String) {
        self.adminKey = adminKey
    }
}

public struct ProviderUsageData: Equatable, Sendable {
    public let costUSD: Decimal?
    public let totalTokens: Int?
    public let requestCount: Int?
    public let limits: [LimitMetric]

    public init(costUSD: Decimal?, totalTokens: Int?, requestCount: Int?, limits: [LimitMetric]) {
        self.costUSD = costUSD
        self.totalTokens = totalTokens
        self.requestCount = requestCount
        self.limits = limits
    }
}

public struct OpenAIClient {
    private let transport: HTTPTransport
    private let baseURL: URL

    public init(transport: HTTPTransport = URLSessionHTTPTransport(), baseURL: URL = URL(string: "https://api.openai.com")!) {
        self.transport = transport
        self.baseURL = baseURL
    }

    public func fetchUsage(configuration: OpenAIConfiguration, range: APIQueryRange) async throws -> ProviderUsageData {
        let costs: OpenAICostsResponse = try await get(
            path: "/v1/organization/costs",
            queryItems: [
                URLQueryItem(name: "start_time", value: "\(range.startUnixSeconds)"),
                URLQueryItem(name: "end_time", value: "\(range.endUnixSeconds)"),
                URLQueryItem(name: "bucket_width", value: "1d"),
                URLQueryItem(name: "limit", value: "31")
            ],
            apiKey: configuration.adminKey
        )
        let usage: OpenAIUsageResponse = try await get(
            path: "/v1/organization/usage/completions",
            queryItems: [
                URLQueryItem(name: "start_time", value: "\(range.startUnixSeconds)"),
                URLQueryItem(name: "end_time", value: "\(range.endUnixSeconds)"),
                URLQueryItem(name: "bucket_width", value: "1d"),
                URLQueryItem(name: "limit", value: "31")
            ],
            apiKey: configuration.adminKey
        )

        let limits: [LimitMetric]
        if let projectID = configuration.projectID {
            let response: OpenAIRateLimitsResponse = try await get(
                path: "/v1/organization/projects/\(projectID)/rate_limits",
                queryItems: [URLQueryItem(name: "limit", value: "100")],
                apiKey: configuration.adminKey
            )
            limits = response.metrics
        } else {
            limits = []
        }

        return ProviderUsageData(
            costUSD: costs.totalUSD,
            totalTokens: usage.totalTokens,
            requestCount: usage.requestCount,
            limits: limits
        )
    }

    private func get<Response: Decodable>(
        path: String,
        queryItems: [URLQueryItem],
        apiKey: String
    ) async throws -> Response {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        components.path = path
        components.queryItems = queryItems

        guard let url = components.url else {
            throw ProviderClientError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("LimitLens/1.0", forHTTPHeaderField: "User-Agent")

        return try await decode(request)
    }

    private func decode<Response: Decodable>(_ request: URLRequest) async throws -> Response {
        do {
            let (data, response) = try await transport.data(for: request)
            try validate(response: response, data: data)
            return try JSONDecoder().decode(Response.self, from: data)
        } catch let error as ProviderClientError {
            throw error
        } catch let error as DecodingError {
            throw ProviderClientError.decoding(error.readableDescription)
        } catch {
            throw ProviderClientError.network(error.localizedDescription)
        }
    }
}

public struct AnthropicClient {
    private let transport: HTTPTransport
    private let baseURL: URL

    public init(transport: HTTPTransport = URLSessionHTTPTransport(), baseURL: URL = URL(string: "https://api.anthropic.com")!) {
        self.transport = transport
        self.baseURL = baseURL
    }

    public func fetchUsage(configuration: AnthropicConfiguration, range: APIQueryRange) async throws -> ProviderUsageData {
        let costs: AnthropicCostResponse = try await get(
            path: "/v1/organizations/cost_report",
            queryItems: [
                URLQueryItem(name: "starting_at", value: range.startRFC3339),
                URLQueryItem(name: "ending_at", value: range.endRFC3339),
                URLQueryItem(name: "bucket_width", value: "1d"),
                URLQueryItem(name: "limit", value: "31")
            ],
            apiKey: configuration.adminKey
        )
        let usage: AnthropicUsageResponse = try await get(
            path: "/v1/organizations/usage_report/messages",
            queryItems: [
                URLQueryItem(name: "starting_at", value: range.startRFC3339),
                URLQueryItem(name: "ending_at", value: range.endRFC3339),
                URLQueryItem(name: "bucket_width", value: "1d"),
                URLQueryItem(name: "limit", value: "31")
            ],
            apiKey: configuration.adminKey
        )
        let limits: AnthropicRateLimitsResponse = try await get(
            path: "/v1/organizations/rate_limits",
            queryItems: [URLQueryItem(name: "group_type", value: "model_group")],
            apiKey: configuration.adminKey
        )

        return ProviderUsageData(
            costUSD: costs.totalUSD,
            totalTokens: usage.totalTokens,
            requestCount: nil,
            limits: limits.metrics
        )
    }

    private func get<Response: Decodable>(
        path: String,
        queryItems: [URLQueryItem],
        apiKey: String
    ) async throws -> Response {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        components.path = path
        components.queryItems = queryItems

        guard let url = components.url else {
            throw ProviderClientError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("LimitLens/1.0", forHTTPHeaderField: "User-Agent")

        return try await decode(request)
    }

    private func decode<Response: Decodable>(_ request: URLRequest) async throws -> Response {
        do {
            let (data, response) = try await transport.data(for: request)
            try validate(response: response, data: data)
            return try JSONDecoder().decode(Response.self, from: data)
        } catch let error as ProviderClientError {
            throw error
        } catch let error as DecodingError {
            throw ProviderClientError.decoding(error.readableDescription)
        } catch {
            throw ProviderClientError.network(error.localizedDescription)
        }
    }
}

private struct OpenAICostsResponse: Decodable {
    let data: [Bucket]

    var totalUSD: Decimal {
        data.flatMap(\.results).reduce(Decimal.zero) { $0 + $1.amount.value }
    }

    struct Bucket: Decodable {
        let results: [Result]
    }

    struct Result: Decodable {
        let amount: Amount
    }

    struct Amount: Decodable {
        let value: Decimal

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            value = try container.decodeFlexibleDecimal(forKey: .value)
        }

        private enum CodingKeys: String, CodingKey {
            case value
        }
    }
}

private struct OpenAIUsageResponse: Decodable {
    let data: [Bucket]

    var totalTokens: Int {
        data.flatMap(\.results).reduce(0) { total, result in
            total + result.inputTokens + result.outputTokens
        }
    }

    var requestCount: Int {
        data.flatMap(\.results).reduce(0) { $0 + $1.numModelRequests }
    }

    struct Bucket: Decodable {
        let results: [Result]
    }

    struct Result: Decodable {
        let inputTokens: Int
        let outputTokens: Int
        let numModelRequests: Int

        private enum CodingKeys: String, CodingKey {
            case inputTokens = "input_tokens"
            case outputTokens = "output_tokens"
            case numModelRequests = "num_model_requests"
        }
    }
}

private struct OpenAIRateLimitsResponse: Decodable {
    let data: [RateLimit]

    var metrics: [LimitMetric] {
        data.map { item in
            let rpm = item.maxRequestsPerMinute.map { "\(MetricFormatter.compactInteger($0)) RPM" }
            let tpm = item.maxTokensPerMinute.map { "\(MetricFormatter.compactInteger($0)) TPM" }
            return LimitMetric(
                id: item.id,
                title: item.model,
                value: [rpm, tpm].compactMap { $0 }.joined(separator: " · "),
                detail: nil
            )
        }
    }

    struct RateLimit: Decodable {
        let id: String
        let model: String
        let maxRequestsPerMinute: Int?
        let maxTokensPerMinute: Int?

        private enum CodingKeys: String, CodingKey {
            case id
            case model
            case maxRequestsPerMinute = "max_requests_per_1_minute"
            case maxTokensPerMinute = "max_tokens_per_1_minute"
        }
    }
}

private struct AnthropicCostResponse: Decodable {
    let data: [Bucket]

    var totalUSD: Decimal {
        let cents = data.flatMap(\.results).reduce(Decimal.zero) { $0 + $1.amount }
        return cents.dividing(by: Decimal(100))
    }

    struct Bucket: Decodable {
        let results: [Result]
    }

    struct Result: Decodable {
        let amount: Decimal

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            amount = try container.decodeFlexibleDecimal(forKey: .amount)
        }

        private enum CodingKeys: String, CodingKey {
            case amount
        }
    }
}

private struct AnthropicUsageResponse: Decodable {
    let data: [Bucket]

    var totalTokens: Int {
        data.flatMap(\.results).reduce(0) { total, result in
            total
                + result.uncachedInputTokens
                + result.cacheReadInputTokens
                + result.cacheCreation.ephemeral1hInputTokens
                + result.cacheCreation.ephemeral5mInputTokens
                + result.outputTokens
        }
    }

    struct Bucket: Decodable {
        let results: [Result]
    }

    struct Result: Decodable {
        let uncachedInputTokens: Int
        let cacheReadInputTokens: Int
        let cacheCreation: CacheCreation
        let outputTokens: Int

        private enum CodingKeys: String, CodingKey {
            case uncachedInputTokens = "uncached_input_tokens"
            case cacheReadInputTokens = "cache_read_input_tokens"
            case cacheCreation = "cache_creation"
            case outputTokens = "output_tokens"
        }
    }

    struct CacheCreation: Decodable {
        let ephemeral1hInputTokens: Int
        let ephemeral5mInputTokens: Int

        private enum CodingKeys: String, CodingKey {
            case ephemeral1hInputTokens = "ephemeral_1h_input_tokens"
            case ephemeral5mInputTokens = "ephemeral_5m_input_tokens"
        }
    }
}

private struct AnthropicRateLimitsResponse: Decodable {
    let data: [RateLimit]

    var metrics: [LimitMetric] {
        data.enumerated().map { index, item in
            let rpm = item.limitValue(type: "requests_per_minute").map { "\(MetricFormatter.compactInteger($0)) RPM" }
            let itpm = item.limitValue(type: "input_tokens_per_minute").map { "\(MetricFormatter.compactInteger($0)) ITPM" }
            let otpm = item.limitValue(type: "output_tokens_per_minute").map { "\(MetricFormatter.compactInteger($0)) OTPM" }
            return LimitMetric(
                id: item.models.first ?? "anthropic-limit-\(index)",
                title: item.models.first ?? "Model group",
                value: [rpm, itpm, otpm].compactMap { $0 }.joined(separator: " · "),
                detail: item.models.dropFirst().joined(separator: ", ").nilIfEmpty
            )
        }
    }

    struct RateLimit: Decodable {
        let models: [String]
        let limits: [Limit]

        func limitValue(type: String) -> Int? {
            limits.first { $0.type == type }?.value
        }
    }

    struct Limit: Decodable {
        let type: String
        let value: Int
    }
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

private extension KeyedDecodingContainer {
    func decodeFlexibleDecimal(forKey key: Key) throws -> Decimal {
        if let string = try? decode(String.self, forKey: key), let decimal = Decimal(string: string) {
            return decimal
        }
        if let double = try? decode(Double.self, forKey: key), let decimal = Decimal(string: String(double)) {
            return decimal
        }
        if let int = try? decode(Int.self, forKey: key) {
            return Decimal(int)
        }
        throw DecodingError.dataCorruptedError(forKey: key, in: self, debugDescription: "Expected decimal string or number")
    }
}

private extension Decimal {
    func dividing(by divisor: Decimal) -> Decimal {
        var lhs = self
        var rhs = divisor
        var result = Decimal()
        NSDecimalDivide(&result, &lhs, &rhs, .plain)
        return result
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

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
