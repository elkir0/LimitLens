import XCTest
@testable import LimitLensCore

final class ProviderCredentialImporterTests: XCTestCase {
    func testImportsClaudeCodeTokenIntoLimitLensKeychainAccount() async throws {
        let source = StaticImporterClaudeOAuthStore(token: "oauth-token")
        let destination = MemorySecretStore()
        let importer = ClaudeCredentialImporter(source: source, destination: destination)

        try await importer.importClaudeCodeToken()

        XCTAssertEqual(
            try destination.readSecret(account: ClaudeCredentialImporter.limitLensClaudeAccount),
            "oauth-token"
        )
    }

    func testImportFailsWhenClaudeCodeTokenIsMissing() async {
        let importer = ClaudeCredentialImporter(
            source: StaticImporterClaudeOAuthStore(token: nil),
            destination: MemorySecretStore()
        )

        await XCTAssertThrowsErrorAsync {
            try await importer.importClaudeCodeToken()
        }
    }
}

private struct StaticImporterClaudeOAuthStore: ClaudeOAuthStore {
    let token: String?

    func readAccessToken() async throws -> String? {
        token
    }
}

private final class MemorySecretStore: SecretStore {
    private var values: [String: String] = [:]

    func readSecret(account: String) throws -> String? {
        values[account]
    }

    func saveSecret(_ secret: String, account: String) throws {
        values[account] = secret
    }

    func deleteSecret(account: String) throws {
        values.removeValue(forKey: account)
    }
}

private func XCTAssertThrowsErrorAsync(
    _ expression: () async throws -> Void,
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        try await expression()
        XCTFail("Expected error", file: file, line: line)
    } catch {}
}
