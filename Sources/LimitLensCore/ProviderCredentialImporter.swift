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

public protocol ClaudeCredentialSyncing {
    func syncAccessTokenIfAvailable() async -> Bool
}

public struct SyncedClaudeOAuthStore: ClaudeOAuthStore, ClaudeCredentialSyncing {
    private let source: ClaudeOAuthStore
    private let destination: SecretStore

    public init(
        source: ClaudeOAuthStore = ClaudeCodeKeychainOAuthStore(),
        destination: SecretStore = SystemKeychainStore()
    ) {
        self.source = source
        self.destination = destination
    }

    public func readAccessToken() async throws -> String? {
        let syncResult = await syncAccessToken()
        if let token = syncResult.token {
            return token
        }
        if let error = syncResult.error {
            throw error
        }
        return nil
    }

    public func syncAccessTokenIfAvailable() async -> Bool {
        await syncAccessToken().changed
    }

    private func syncAccessToken() async -> CredentialSyncResult {
        let importedToken = normalized(try? destination.readSecret(
            account: ClaudeCredentialImporter.limitLensClaudeAccount
        ))

        do {
            guard let currentToken = normalized(try await source.readAccessToken()) else {
                return CredentialSyncResult(token: importedToken, changed: false, error: nil)
            }
            if currentToken != importedToken {
                try destination.saveSecret(currentToken, account: ClaudeCredentialImporter.limitLensClaudeAccount)
                return CredentialSyncResult(token: currentToken, changed: true, error: nil)
            }
            return CredentialSyncResult(token: currentToken, changed: false, error: nil)
        } catch {
            if let importedToken {
                return CredentialSyncResult(token: importedToken, changed: false, error: nil)
            }
            return CredentialSyncResult(token: nil, changed: false, error: error)
        }
    }
}

private struct CredentialSyncResult {
    let token: String?
    let changed: Bool
    let error: Error?
}

private func normalized(_ token: String?) -> String? {
    token?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
