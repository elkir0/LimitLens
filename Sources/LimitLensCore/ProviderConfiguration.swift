import Foundation

public enum ProviderMode: String, Codable, Equatable, Sendable {
    case enabled
    case disabled
}

public enum ProviderSetupState: String, Codable, Equatable, Sendable {
    case disabled
    case needsSetup
    case active
    case degraded
    case error
}

public struct ProviderSettings: Codable, Equatable, Sendable {
    public var mode: ProviderMode
    public var folderBookmark: Data?
    public var claudeExactEnabled: Bool
    public var claudeCredentialImported: Bool

    public init(
        mode: ProviderMode = .enabled,
        folderBookmark: Data? = nil,
        claudeExactEnabled: Bool = false,
        claudeCredentialImported: Bool = false
    ) {
        self.mode = mode
        self.folderBookmark = folderBookmark
        self.claudeExactEnabled = claudeExactEnabled
        self.claudeCredentialImported = claudeCredentialImported
    }
}

public struct ProviderConfiguration: Codable, Equatable, Sendable {
    public static let storageKey = "LimitLens.ProviderConfiguration.v1"

    public private(set) var providers: [CLIUsageSource: ProviderSettings]
    public private(set) var hasCompletedOnboarding: Bool

    private enum CodingKeys: String, CodingKey {
        case providers
        case hasCompletedOnboarding
    }

    public static var defaultEnabled: ProviderConfiguration {
        ProviderConfiguration(providers: [
            .claudeCode: ProviderSettings(),
            .codex: ProviderSettings()
        ])
    }

    public init(
        providers: [CLIUsageSource: ProviderSettings],
        hasCompletedOnboarding: Bool = false
    ) {
        self.providers = providers
        self.hasCompletedOnboarding = hasCompletedOnboarding
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.providers = try container.decode([CLIUsageSource: ProviderSettings].self, forKey: .providers)
        self.hasCompletedOnboarding = try container.decodeIfPresent(
            Bool.self,
            forKey: .hasCompletedOnboarding
        ) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(providers, forKey: .providers)
        try container.encode(hasCompletedOnboarding, forKey: .hasCompletedOnboarding)
    }

    public var activeSources: [CLIUsageSource] {
        CLIUsageSource.allCases.filter { providers[$0]?.mode == .enabled }
    }

    public var requiresOnboarding: Bool {
        guard !hasCompletedOnboarding else {
            return false
        }
        return activeSources.contains { setupState(for: $0) == .needsSetup }
    }

    public mutating func setMode(_ mode: ProviderMode, for source: CLIUsageSource) {
        var settings = providers[source] ?? ProviderSettings()
        settings.mode = mode
        providers[source] = settings
    }

    public mutating func setFolderBookmark(_ bookmark: Data?, for source: CLIUsageSource) {
        var settings = providers[source] ?? ProviderSettings()
        settings.folderBookmark = bookmark
        providers[source] = settings
    }

    public mutating func setClaudeExactEnabled(_ enabled: Bool) {
        var settings = providers[.claudeCode] ?? ProviderSettings()
        settings.claudeExactEnabled = enabled
        providers[.claudeCode] = settings
    }

    public mutating func setClaudeCredentialImported(_ imported: Bool) {
        var settings = providers[.claudeCode] ?? ProviderSettings()
        settings.claudeCredentialImported = imported
        providers[.claudeCode] = settings
    }

    public mutating func markOnboardingCompleted() {
        hasCompletedOnboarding = true
    }

    public func setupState(for source: CLIUsageSource) -> ProviderSetupState {
        guard let settings = providers[source], settings.mode == .enabled else {
            return .disabled
        }

        switch source {
        case .codex:
            return settings.folderBookmark == nil ? .needsSetup : .active
        case .claudeCode:
            guard settings.folderBookmark != nil else {
                return .needsSetup
            }
            if settings.claudeExactEnabled && !settings.claudeCredentialImported {
                return .degraded
            }
            return .active
        }
    }
}
