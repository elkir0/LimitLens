import XCTest
@testable import LimitLensCore

final class DateRangeTests: XCTestCase {
    func testMonthToDateStartsAtFirstDayUTC() {
        let now = Date(timeIntervalSince1970: 1_747_500_000)
        let range = APIQueryRange.monthToDate(now: now)

        XCTAssertEqual(range.startUnixSeconds, 1_746_057_600)
        XCTAssertEqual(range.endUnixSeconds, 1_747_500_000)
        XCTAssertEqual(range.startRFC3339, "2025-05-01T00:00:00Z")
        XCTAssertEqual(range.endRFC3339, "2025-05-17T16:40:00Z")
    }
}
