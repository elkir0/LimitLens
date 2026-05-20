import XCTest
@testable import LimitLensCore

final class MenuBarSummaryTests: XCTestCase {
    func testPicksLowestRemainingAcrossProviders() {
        let summary = MenuBarSummary.make(from: [
            snapshot(.claudeCode, usedPercents: [33, 26]),
            snapshot(.codex, usedPercents: [15, 60])
        ])
        // Highest utilization is 60 -> lowest remaining is 40.
        XCTAssertEqual(summary.remainingText, "40%")
        XCTAssertEqual(summary.health, .ok)
    }

    func testHealthIsErrorWhenUtilizationAtLeast95() {
        let summary = MenuBarSummary.make(from: [snapshot(.codex, usedPercents: [96])])
        XCTAssertEqual(summary.remainingText, "4%")
        XCTAssertEqual(summary.health, .error)
    }

    func testHealthIsWarningWhenUtilizationAtLeast75() {
        let summary = MenuBarSummary.make(from: [snapshot(.codex, usedPercents: [80])])
        XCTAssertEqual(summary.health, .warning)
    }

    func testNilWhenNoLimitsAvailable() {
        let summary = MenuBarSummary.make(from: [
            .unavailable(source: .claudeCode, note: "x"),
            .unavailable(source: .codex, note: "y")
        ])
        XCTAssertNil(summary.remainingText)
        XCTAssertEqual(summary.health, .unavailable)
    }

    func testIgnoresLimitsWithoutUtilization() {
        let mixed = CLIUsageSnapshot(
            source: .claudeCode,
            health: .ok,
            summary: "x",
            limits: [
                UsageLimitState(id: "a", label: "A", usedPercent: nil, resetDate: nil, detail: ""),
                UsageLimitState(id: "b", label: "B", usedPercent: 70, resetDate: nil, detail: "")
            ],
            metrics: [],
            lastUpdated: nil,
            note: nil
        )
        let summary = MenuBarSummary.make(from: [mixed])
        XCTAssertEqual(summary.remainingText, "30%")
    }

    func testHealthReflectsUnavailableProviderEvenWhenOtherIsHealthy() {
        let summary = MenuBarSummary.make(from: [
            snapshot(.claudeCode, usedPercents: [30]),
            .unavailable(source: .codex, note: "Codex illisible")
        ])
        // The healthy provider sits at 30% used; the other provider is down.
        XCTAssertEqual(summary.remainingText, "70%")
        XCTAssertEqual(summary.health, .unavailable)
    }

    private func snapshot(_ source: CLIUsageSource, usedPercents: [Double]) -> CLIUsageSnapshot {
        CLIUsageSnapshot(
            source: source,
            health: .ok,
            summary: "x",
            limits: usedPercents.enumerated().map { index, percent in
                UsageLimitState(id: "\(index)", label: "L\(index)", usedPercent: percent, resetDate: nil, detail: "")
            },
            metrics: [],
            lastUpdated: nil,
            note: nil
        )
    }
}
