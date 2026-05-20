import XCTest
@testable import LimitLensCore

final class SecurityScopedBookmarkTests: XCTestCase {
    func testFakeBookmarkStoreRoundTripsFolderURL() throws {
        let store = InMemoryFolderBookmarkStore()
        let url = URL(fileURLWithPath: "/Users/test/.codex/sessions", isDirectory: true)

        let data = try store.bookmarkData(for: url)
        let access = try store.resolve(data)

        XCTAssertEqual(access.url, url)
        XCTAssertFalse(access.isStale)
        XCTAssertTrue(access.startAccessing())
        access.stopAccessing()
    }

    func testProviderConfigurationStorePersistsBookmarks() throws {
        let suiteName = "ProviderConfigurationStoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = ProviderConfigurationStore(userDefaults: defaults)
        var configuration = ProviderConfiguration.defaultEnabled
        configuration.setFolderBookmark(Data("codex".utf8), for: .codex)

        try store.save(configuration)

        XCTAssertEqual(try store.load(), configuration)
    }
}
