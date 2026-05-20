import Foundation
import XCTest
@testable import LimitLensCore

final class ClaudeCodeUsageClientTests: XCTestCase {
    func testFetchUsageBuildsOAuthRequestAndMapsUsageSnapshot() async throws {
        let transport = FakeClaudeHTTPTransport(response: .json(claudeCodeUsageJSON))
        let client = ClaudeCodeUsageClient(transport: transport)
        let now = ISO8601DateFormatter().date(from: "2026-05-17T23:30:00Z")!

        let snapshot = try await client.fetchUsageSnapshot(oauthToken: "oauth-token", now: now)

        XCTAssertEqual(transport.requests.count, 1)
        XCTAssertEqual(transport.requests[0].url?.path, "/api/oauth/usage")
        XCTAssertEqual(transport.requests[0].value(forHTTPHeaderField: "Authorization"), "Bearer oauth-token")
        XCTAssertEqual(transport.requests[0].value(forHTTPHeaderField: "anthropic-beta"), "oauth-2025-04-20")
        XCTAssertEqual(snapshot.source, .claudeCode)
        XCTAssertEqual(snapshot.summary, "Exact /usage")
        XCTAssertEqual(snapshot.health, .ok)
        XCTAssertEqual(snapshot.limits.map(\.id), ["five_hour", "seven_day", "seven_day_sonnet", "extra_usage"])
        XCTAssertEqual(snapshot.limits[0].label, "Session courante")
        XCTAssertEqual(snapshot.limits[0].usedPercent, 11)
        XCTAssertEqual(snapshot.limits[1].label, "Semaine courante")
        XCTAssertEqual(snapshot.limits[1].usedPercent, 15)
        XCTAssertEqual(snapshot.limits[2].label, "Sonnet 7j")
        XCTAssertEqual(snapshot.limits[2].usedPercent, 11)
        XCTAssertEqual(snapshot.limits[3].label, "Extra usage")
        XCTAssertEqual(snapshot.limits[3].usedPercent, 33.94285714285714)
        XCTAssertEqual(snapshot.limits[3].detail, "$47.52 / $140.00")
        XCTAssertNil(snapshot.limits[3].resetDate)
        XCTAssertEqual(snapshot.metrics.first?.value, "Max")
        XCTAssertEqual(snapshot.lastUpdated, now)
        XCTAssertEqual(snapshot.note, "Lu depuis le endpoint OAuth Claude Code.")
    }

    func testUsageResponseWithDisabledExtraUsageDecodesSuccessfully() async throws {
        let transport = FakeClaudeHTTPTransport(response: .json(claudeCodeUsageDisabledExtraJSON))
        let client = ClaudeCodeUsageClient(transport: transport)
        let now = ISO8601DateFormatter().date(from: "2026-05-18T20:00:00Z")!

        let snapshot = try await client.fetchUsageSnapshot(oauthToken: "oauth-token", now: now)

        XCTAssertEqual(snapshot.limits.map(\.id), ["five_hour", "seven_day", "seven_day_sonnet"])
        XCTAssertEqual(snapshot.limits[0].usedPercent, 12)
        XCTAssertEqual(snapshot.health, .ok)
    }

    func testUnauthorizedUsageResponseMapsToProviderError() async throws {
        let transport = FakeClaudeHTTPTransport(response: .json("{}", statusCode: 401))
        let client = ClaudeCodeUsageClient(transport: transport)

        do {
            _ = try await client.fetchUsageSnapshot(oauthToken: "expired", now: Date())
            XCTFail("Expected unauthorized error")
        } catch let error as ProviderClientError {
            XCTAssertEqual(error, .unauthorized)
        }
    }
}

private final class FakeClaudeHTTPTransport: HTTPTransport {
    private(set) var requests: [URLRequest] = []
    private let response: FakeClaudeHTTPResponse

    init(response: FakeClaudeHTTPResponse) {
        self.response = response
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        let http = HTTPURLResponse(
            url: request.url!,
            statusCode: response.statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: response.headers
        )!
        return (response.data, http)
    }
}

private struct FakeClaudeHTTPResponse {
    let data: Data
    let statusCode: Int
    let headers: [String: String]

    static func json(_ string: String, statusCode: Int = 200, headers: [String: String] = [:]) -> FakeClaudeHTTPResponse {
        FakeClaudeHTTPResponse(data: Data(string.utf8), statusCode: statusCode, headers: headers)
    }
}

private let claudeCodeUsageJSON = """
{
  "five_hour": {
    "utilization": 11.0,
    "resets_at": "2026-05-18T04:10:00.288779+00:00"
  },
  "seven_day": {
    "utilization": 15.0,
    "resets_at": "2026-05-22T02:00:00.288802+00:00"
  },
  "seven_day_oauth_apps": null,
  "seven_day_opus": null,
  "seven_day_sonnet": {
    "utilization": 11.0,
    "resets_at": "2026-05-22T02:00:00.288811+00:00"
  },
  "seven_day_cowork": null,
  "seven_day_omelette": {
    "utilization": 0.0,
    "resets_at": null
  },
  "tangelo": null,
  "iguana_necktie": null,
  "omelette_promotional": null,
  "extra_usage": {
    "is_enabled": true,
    "monthly_limit": 14000,
    "used_credits": 4752.0,
    "utilization": 33.94285714285714,
    "currency": "USD",
    "disabled_reason": null
  }
}
"""

private let claudeCodeUsageDisabledExtraJSON = """
{
  "five_hour": {
    "utilization": 12.0,
    "resets_at": "2026-05-19T02:20:00.658277+00:00"
  },
  "seven_day": {
    "utilization": 33.0,
    "resets_at": "2026-05-22T02:00:00.658299+00:00"
  },
  "seven_day_oauth_apps": null,
  "seven_day_opus": null,
  "seven_day_sonnet": {
    "utilization": 26.0,
    "resets_at": "2026-05-22T02:00:00.658306+00:00"
  },
  "seven_day_cowork": null,
  "seven_day_omelette": {
    "utilization": 0.0,
    "resets_at": null
  },
  "tangelo": null,
  "iguana_necktie": null,
  "omelette_promotional": null,
  "extra_usage": {
    "is_enabled": false,
    "monthly_limit": null,
    "used_credits": null,
    "utilization": null,
    "currency": null,
    "disabled_reason": null
  }
}
"""
