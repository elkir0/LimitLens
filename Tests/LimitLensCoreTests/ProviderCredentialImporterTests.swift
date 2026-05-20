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

    func testSyncedClaudeOAuthStoreRefreshesImportedTokenFromClaudeCode() async throws {
        let destination = MemorySecretStore()
        try destination.saveSecret("stale-token", account: ClaudeCredentialImporter.limitLensClaudeAccount)
        let store = SyncedClaudeOAuthStore(
            source: StaticImporterClaudeOAuthStore(token: "fresh-token"),
            destination: destination
        )

        let token = try await store.readAccessToken()

        XCTAssertEqual(token, "fresh-token")
        XCTAssertEqual(
            try destination.readSecret(account: ClaudeCredentialImporter.limitLensClaudeAccount),
            "fresh-token"
        )
    }

    func testSyncedClaudeOAuthStoreFallsBackToImportedTokenWhenClaudeCodeTokenIsUnavailable() async throws {
        let destination = MemorySecretStore()
        try destination.saveSecret("imported-token", account: ClaudeCredentialImporter.limitLensClaudeAccount)
        let store = SyncedClaudeOAuthStore(
            source: StaticImporterClaudeOAuthStore(token: nil),
            destination: destination
        )

        let token = try await store.readAccessToken()

        XCTAssertEqual(token, "imported-token")
    }

    func testClaudeCodeOAuthStoreTriesFallbackKeychainAccounts() async throws {
        let executable = try fakeSecurityExecutable(foundAccount: "root", token: "oauth-root-token")
        let store = ClaudeCodeKeychainOAuthStore(
            accounts: ["example-user", "root"],
            securityExecutable: executable,
            timeout: 2
        )

        let token = try await store.readAccessToken()

        XCTAssertEqual(token, "oauth-root-token")
    }

    func testClaudeCodeOAuthStoreReturnsNilWhenNoCandidateAccountExists() async throws {
        let executable = try fakeSecurityExecutable(foundAccount: "nobody", token: "oauth-token")
        let store = ClaudeCodeKeychainOAuthStore(
            accounts: ["example-user", "root"],
            securityExecutable: executable,
            timeout: 2
        )

        let token = try await store.readAccessToken()

        XCTAssertNil(token)
    }

    private func fakeSecurityExecutable(foundAccount: String, token: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LimitLensSecurityTests")
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let executable = directory.appendingPathComponent("security")
        try """
        #!/bin/sh
        account=""
        while [ "$#" -gt 0 ]; do
          case "$1" in
            -a)
              shift
              account="$1"
              ;;
          esac
          shift
        done
        if [ "$account" = "\(foundAccount)" ]; then
          printf '%s' '{"claudeAiOauth":{"accessToken":"\(token)"}}'
          exit 0
        fi
        echo 'security: SecKeychainSearchCopyNext: The specified item could not be found in the keychain.' >&2
        exit 44
        """.write(to: executable, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: executable.path
        )
        return executable
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
