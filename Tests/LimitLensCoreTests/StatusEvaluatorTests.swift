import XCTest
@testable import LimitLensCore

final class StatusEvaluatorTests: XCTestCase {
    func testMissingKeyMapsToUnconfigured() {
        let snapshot = StatusEvaluator.snapshot(
            provider: .openAI,
            credentialsPresent: false,
            costUSD: nil,
            totalTokens: nil,
            requestCount: nil,
            limits: [],
            error: nil,
            now: Date(timeIntervalSince1970: 1_800_000_000)
        )

        XCTAssertEqual(snapshot.health, .unconfigured)
        XCTAssertEqual(snapshot.summary, "Key missing")
    }

    func testUnauthorizedMapsToError() {
        let snapshot = StatusEvaluator.snapshot(
            provider: .anthropic,
            credentialsPresent: true,
            costUSD: nil,
            totalTokens: nil,
            requestCount: nil,
            limits: [],
            error: .unauthorized,
            now: Date(timeIntervalSince1970: 1_800_000_000)
        )

        XCTAssertEqual(snapshot.health, .error)
        XCTAssertEqual(snapshot.summary, "Invalid key")
    }

    func testUsageMetricsUseDisplayFormatting() {
        let snapshot = StatusEvaluator.snapshot(
            provider: .openAI,
            credentialsPresent: true,
            costUSD: Decimal(string: "12.34"),
            totalTokens: 1_240_000,
            requestCount: 1_240,
            limits: [],
            error: nil,
            now: Date(timeIntervalSince1970: 1_800_000_000)
        )

        XCTAssertEqual(snapshot.usageMetrics.map(\.value), ["$12.34", "1.2M tok", "1.2K"])
    }
}
