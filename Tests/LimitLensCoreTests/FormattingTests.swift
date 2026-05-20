import XCTest
@testable import LimitLensCore

final class FormattingTests: XCTestCase {
    func testCurrencyUsesUSDDisplay() {
        let value = Decimal(string: "12.34")!

        XCTAssertEqual(MetricFormatter.currencyUSD(value), "$12.34")
    }

    func testCompactIntegerUsesReadableSuffixes() {
        XCTAssertEqual(MetricFormatter.compactInteger(950), "950")
        XCTAssertEqual(MetricFormatter.compactInteger(1_240), "1.2K")
        XCTAssertEqual(MetricFormatter.compactInteger(1_240_000), "1.2M")
    }

    func testTokensAppendTokenUnit() {
        XCTAssertEqual(MetricFormatter.tokens(1_240_000), "1.2M tok")
    }

    func testWeekdayDateTimeIncludesDayDateAndTime() {
        let date = Date(timeIntervalSince1970: 1_779_646_918)
        let timeZone = TimeZone(secondsFromGMT: -4 * 60 * 60)!

        XCTAssertEqual(
            MetricFormatter.weekdayDateTime(date, timeZone: timeZone),
            "dim. 24/05 14:21"
        )
    }
}
