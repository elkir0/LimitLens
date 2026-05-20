import Foundation
import LimitLensCore

@MainActor
final class LimitLensAppModel: ObservableObject {
    @Published private(set) var configuration: ProviderConfiguration
    @Published private(set) var usageStore: LocalUsageStore
    @Published var setupMessage: String?

    private let configurationStore: ProviderConfigurationStore
    private let bookmarkStore: FolderBookmarkStore
    private let credentialImporter: ClaudeCredentialImporter
    private let secretStore: SecretStore
    private var scopedAccess: [CLIUsageSource: ScopedFolderAccess] = [:]

    init(
        configurationStore: ProviderConfigurationStore = ProviderConfigurationStore(),
        bookmarkStore: FolderBookmarkStore = SecurityScopedFolderBookmarkStore(),
        credentialImporter: ClaudeCredentialImporter = ClaudeCredentialImporter(),
        secretStore: SecretStore = SystemKeychainStore()
    ) {
        self.configurationStore = configurationStore
        self.bookmarkStore = bookmarkStore
        self.credentialImporter = credentialImporter
        self.secretStore = secretStore
        let loadedConfiguration = (try? configurationStore.load()) ?? .defaultEnabled
        self.configuration = loadedConfiguration
        var initialScopedAccess: [CLIUsageSource: ScopedFolderAccess] = [:]
        self.usageStore = Self.makeUsageStore(
            configuration: loadedConfiguration,
            bookmarkStore: bookmarkStore,
            scopedAccess: &initialScopedAccess
        )
        self.scopedAccess = initialScopedAccess
    }

    deinit {
        for access in scopedAccess.values {
            access.stopAccessing()
        }
    }

    func setProvider(_ source: CLIUsageSource, enabled: Bool) {
        configuration.setMode(enabled ? .enabled : .disabled, for: source)
        persistAndRebuild()
    }

    func saveFolderBookmark(_ bookmark: Data, for source: CLIUsageSource) {
        configuration.setFolderBookmark(bookmark, for: source)
        persistAndRebuild()
    }

    func importClaudeCredentials() async {
        do {
            try await credentialImporter.importClaudeCodeToken()
            configuration.setClaudeExactEnabled(true)
            configuration.setClaudeCredentialImported(true)
            setupMessage = String(localized: "setup.importClaude.success")
            persistAndRebuild()
        } catch {
            configuration.setClaudeExactEnabled(true)
            configuration.setClaudeCredentialImported(false)
            setupMessage = String(localized: "setup.importClaude.failure")
            persistAndRebuild()
        }
    }

    func resetProvider(_ source: CLIUsageSource) {
        configuration.setFolderBookmark(nil, for: source)
        if source == .claudeCode {
            configuration.setClaudeExactEnabled(false)
            configuration.setClaudeCredentialImported(false)
            try? secretStore.deleteSecret(account: ClaudeCredentialImporter.limitLensClaudeAccount)
        }
        persistAndRebuild()
    }

    func finishOnboarding() {
        setupMessage = nil
        configuration.markOnboardingCompleted()
        persistAndRebuild()
    }

    private func persistAndRebuild() {
        do {
            try configurationStore.save(configuration)
            rebuildUsageStore()
        } catch {
            setupMessage = String(localized: "setup.save.failure")
        }
    }

    private func rebuildUsageStore() {
        for access in scopedAccess.values {
            access.stopAccessing()
        }
        scopedAccess.removeAll()
        usageStore = Self.makeUsageStore(
            configuration: configuration,
            bookmarkStore: bookmarkStore,
            scopedAccess: &scopedAccess
        )
    }

    private static func makeUsageStore(
        configuration: ProviderConfiguration,
        bookmarkStore: FolderBookmarkStore,
        scopedAccess: inout [CLIUsageSource: ScopedFolderAccess]
    ) -> LocalUsageStore {
        var folders: [CLIUsageSource: URL] = [:]
        for source in configuration.activeSources {
            guard
                let bookmark = configuration.providers[source]?.folderBookmark,
                let access = try? bookmarkStore.resolve(bookmark)
            else {
                continue
            }
            guard access.startAccessing() else {
                continue
            }
            scopedAccess[source] = access
            folders[source] = access.url
        }

        let reader = LocalUsageReader(
            providerFolders: folders,
            claudeOAuthStore: LimitLensClaudeOAuthStore()
        )
        return LocalUsageStore(
            reader: reader,
            configuration: configuration
        )
    }
}
