import XCTest
@testable import LimitLensCore

final class RefreshIntervalTests: XCTestCase {
    func testSupportedRefreshIntervalsExposeDisplayLabels() {
        XCTAssertEqual(RefreshInterval.allCases.map(\.rawValue), [30, 60, 120, 300, 600])
        XCTAssertEqual(RefreshInterval.seconds30.displayLabel, "30 secondes")
        XCTAssertEqual(RefreshInterval.seconds120.shortLabel, "120s")
        XCTAssertEqual(RefreshInterval.minutes5.shortLabel, "5 min")
    }

    func testInvalidStoredValueFallsBackToDefault() {
        XCTAssertEqual(RefreshInterval.resolved(rawValue: 999), .seconds120)
        XCTAssertEqual(RefreshInterval.default, .seconds120)
    }
}
