import XCTest
@testable import LimitLensCore

final class KeychainStoreTests: XCTestCase {
    private var store: SystemKeychainStore!
    private let account = "openai-admin-key"

    override func setUpWithError() throws {
        store = SystemKeychainStore(service: "LimitLensTests-\(UUID().uuidString)")
        try store.deleteSecret(account: account)
    }

    override func tearDownWithError() throws {
        try store.deleteSecret(account: account)
        store = nil
    }

    func testMissingSecretReturnsNil() throws {
        XCTAssertNil(try store.readSecret(account: account))
    }

    func testSaveReadReplaceAndDeleteSecret() throws {
        try store.saveSecret("first", account: account)
        XCTAssertEqual(try store.readSecret(account: account), "first")

        try store.saveSecret("second", account: account)
        XCTAssertEqual(try store.readSecret(account: account), "second")

        try store.deleteSecret(account: account)
        XCTAssertNil(try store.readSecret(account: account))
    }
}
