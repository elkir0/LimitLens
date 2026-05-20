import Foundation

public struct ClaudeCredentialImporter {
    public static let limitLensClaudeAccount = "claude-code-oauth-token"

    private let source: ClaudeOAuthStore
    private let destination: SecretStore

    public init(
        source: ClaudeOAuthStore = ClaudeCodeKeychainOAuthStore(),
        destination: SecretStore = SystemKeychainStore()
    ) {
        self.source = source
        self.destination = destination
    }

    public func importClaudeCodeToken() async throws {
        guard
            let token = try await source.readAccessToken(),
            !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            throw ProviderClientError.missingKey
        }
        try destination.saveSecret(token, account: Self.limitLensClaudeAccount)
    }
}

public struct LimitLensClaudeOAuthStore: ClaudeOAuthStore {
    private let secretStore: SecretStore

    public init(secretStore: SecretStore = SystemKeychainStore()) {
        self.secretStore = secretStore
    }

    public func readAccessToken() async throws -> String? {
        try secretStore.readSecret(account: ClaudeCredentialImporter.limitLensClaudeAccount)
    }
}
