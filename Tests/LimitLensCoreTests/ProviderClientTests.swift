import Foundation
import XCTest
@testable import LimitLensCore

final class ProviderClientTests: XCTestCase {
    func testOpenAIClientBuildsRequestsAndSummarizesResponses() async throws {
        let transport = FakeHTTPTransport(responses: [
            .json(openAICostsJSON),
            .json(openAIUsageJSON),
            .json(openAIRateLimitsJSON)
        ])
        let client = OpenAIClient(transport: transport)
        let range = APIQueryRange(start: Date(timeIntervalSince1970: 1_746_057_600), end: Date(timeIntervalSince1970: 1_747_500_000))

        let data = try await client.fetchUsage(
            configuration: OpenAIConfiguration(adminKey: "test-openai-admin-key", projectID: "proj_123"),
            range: range
        )

        XCTAssertEqual(data.costUSD, Decimal(string: "12.34"))
        XCTAssertEqual(data.totalTokens, 1_750)
        XCTAssertEqual(data.requestCount, 7)
        XCTAssertEqual(data.limits.count, 1)
        XCTAssertEqual(data.limits[0].title, "gpt-5.4")
        XCTAssertEqual(data.limits[0].value, "1.2K RPM · 2M TPM")
        XCTAssertEqual(transport.requests.count, 3)
        XCTAssertEqual(transport.requests[0].url?.path, "/v1/organization/costs")
        XCTAssertEqual(transport.requests[1].url?.path, "/v1/organization/usage/completions")
        XCTAssertEqual(transport.requests[2].url?.path, "/v1/organization/projects/proj_123/rate_limits")
        XCTAssertEqual(transport.requests[0].value(forHTTPHeaderField: "Authorization"), "Bearer test-openai-admin-key")
    }

    func testAnthropicClientBuildsRequestsAndSummarizesResponses() async throws {
        let transport = FakeHTTPTransport(responses: [
            .json(anthropicCostJSON),
            .json(anthropicUsageJSON),
            .json(anthropicLimitsJSON)
        ])
        let client = AnthropicClient(transport: transport)
        let range = APIQueryRange(start: Date(timeIntervalSince1970: 1_746_057_600), end: Date(timeIntervalSince1970: 1_747_500_000))

        let data = try await client.fetchUsage(
            configuration: AnthropicConfiguration(adminKey: "test-anthropic-admin-key"),
            range: range
        )

        XCTAssertEqual(data.costUSD, Decimal(string: "1.25"))
        XCTAssertEqual(data.totalTokens, 2_650)
        XCTAssertNil(data.requestCount)
        XCTAssertEqual(data.limits.count, 1)
        XCTAssertEqual(data.limits[0].title, "claude-sonnet-4")
        XCTAssertEqual(data.limits[0].value, "50 RPM · 30K ITPM · 8K OTPM")
        XCTAssertEqual(transport.requests.count, 3)
        XCTAssertEqual(transport.requests[0].url?.path, "/v1/organizations/cost_report")
        XCTAssertEqual(transport.requests[1].url?.path, "/v1/organizations/usage_report/messages")
        XCTAssertEqual(transport.requests[2].url?.path, "/v1/organizations/rate_limits")
        XCTAssertEqual(transport.requests[0].value(forHTTPHeaderField: "x-api-key"), "test-anthropic-admin-key")
        XCTAssertEqual(transport.requests[0].value(forHTTPHeaderField: "anthropic-version"), "2023-06-01")
    }

    func testUnauthorizedResponseMapsToProviderError() async throws {
        let transport = FakeHTTPTransport(responses: [
            .json("{}", statusCode: 401)
        ])
        let client = OpenAIClient(transport: transport)
        let range = APIQueryRange.monthToDate(now: Date(timeIntervalSince1970: 1_747_500_000))

        do {
            _ = try await client.fetchUsage(
                configuration: OpenAIConfiguration(adminKey: "bad", projectID: nil),
                range: range
            )
            XCTFail("Expected unauthorized error")
        } catch let error as ProviderClientError {
            XCTAssertEqual(error, .unauthorized)
        }
    }
}

private final class FakeHTTPTransport: HTTPTransport {
    private(set) var requests: [URLRequest] = []
    private var responses: [FakeHTTPResponse]

    init(responses: [FakeHTTPResponse]) {
        self.responses = responses
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        let response = responses.removeFirst()
        let http = HTTPURLResponse(
            url: request.url!,
            statusCode: response.statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: response.headers
        )!
        return (response.data, http)
    }
}

private struct FakeHTTPResponse {
    let data: Data
    let statusCode: Int
    let headers: [String: String]

    static func json(_ string: String, statusCode: Int = 200, headers: [String: String] = [:]) -> FakeHTTPResponse {
        FakeHTTPResponse(data: Data(string.utf8), statusCode: statusCode, headers: headers)
    }
}

private let openAICostsJSON = """
{
  "object": "page",
  "data": [
    {
      "object": "bucket",
      "start_time": 1746057600,
      "end_time": 1746144000,
      "results": [
        {
          "object": "organization.costs.result",
          "amount": { "value": 12.34, "currency": "usd" }
        }
      ]
    }
  ],
  "has_more": false
}
"""

private let openAIUsageJSON = """
{
  "object": "page",
  "data": [
    {
      "object": "bucket",
      "start_time": 1746057600,
      "end_time": 1746144000,
      "results": [
        {
          "object": "organization.usage.completions.result",
          "input_tokens": 1000,
          "output_tokens": 750,
          "num_model_requests": 7
        }
      ]
    }
  ],
  "has_more": false
}
"""

private let openAIRateLimitsJSON = """
{
  "object": "list",
  "data": [
    {
      "object": "project.rate_limit",
      "id": "rl_123",
      "model": "gpt-5.4",
      "max_requests_per_1_minute": 1200,
      "max_tokens_per_1_minute": 2000000
    }
  ]
}
"""

private let anthropicCostJSON = """
{
  "data": [
    {
      "starting_at": "2025-05-01T00:00:00Z",
      "ending_at": "2025-05-02T00:00:00Z",
      "results": [
        { "amount": "125.00", "currency": "USD" }
      ]
    }
  ],
  "has_more": false
}
"""

private let anthropicUsageJSON = """
{
  "data": [
    {
      "starting_at": "2025-05-01T00:00:00Z",
      "ending_at": "2025-05-02T00:00:00Z",
      "results": [
        {
          "uncached_input_tokens": 1000,
          "cache_read_input_tokens": 500,
          "cache_creation": {
            "ephemeral_1h_input_tokens": 300,
            "ephemeral_5m_input_tokens": 100
          },
          "output_tokens": 750
        }
      ]
    }
  ],
  "has_more": false
}
"""

private let anthropicLimitsJSON = """
{
  "data": [
    {
      "type": "rate_limit",
      "group_type": "model_group",
      "models": ["claude-sonnet-4"],
      "limits": [
        { "type": "requests_per_minute", "value": 50 },
        { "type": "input_tokens_per_minute", "value": 30000 },
        { "type": "output_tokens_per_minute", "value": 8000 }
      ]
    }
  ]
}
"""
