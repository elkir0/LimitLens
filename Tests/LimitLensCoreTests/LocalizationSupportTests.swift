import XCTest
@testable import LimitLensCore

final class LocalizationSupportTests: XCTestCase {
    func testSupportedLanguagesAreFrenchEnglishSpanish() {
        XCTAssertEqual(SupportedLanguage.allCases.map(\.identifier), ["fr", "en", "es"])
    }

    func testProviderDisplayKeysAreStable() {
        XCTAssertEqual(LocalizationKey.providerName(.codex).rawValue, "provider.openai.name")
        XCTAssertEqual(LocalizationKey.providerName(.claudeCode).rawValue, "provider.claude.name")
    }
}
