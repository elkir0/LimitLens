import Foundation

public enum SupportedLanguage: String, CaseIterable, Sendable {
    case fr
    case en
    case es

    public var identifier: String { rawValue }
}

public struct LocalizationKey: RawRepresentable, Equatable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public static func providerName(_ source: CLIUsageSource) -> LocalizationKey {
        switch source {
        case .codex:
            return LocalizationKey(rawValue: "provider.openai.name")
        case .claudeCode:
            return LocalizationKey(rawValue: "provider.claude.name")
        }
    }
}
