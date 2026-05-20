import XCTest
@testable import LimitLensCore

final class ProviderConfigurationTests: XCTestCase {
    func testDefaultConfigurationRequiresSetupForEnabledProviders() {
        let configuration = ProviderConfiguration.defaultEnabled

        XCTAssertEqual(configuration.providers[.codex]?.mode, .enabled)
        XCTAssertEqual(configuration.providers[.claudeCode]?.mode, .enabled)
        XCTAssertEqual(configuration.setupState(for: .codex), .needsSetup)
        XCTAssertEqual(configuration.setupState(for: .claudeCode), .needsSetup)
    }

    func testDisabledProviderIsExcludedFromActiveSources() {
        var configuration = ProviderConfiguration.defaultEnabled
        configuration.setMode(.disabled, for: .claudeCode)

        XCTAssertEqual(configuration.activeSources, [.codex])
        XCTAssertEqual(configuration.setupState(for: .claudeCode), .disabled)
    }

    func testCodexIsActiveWhenBookmarkExists() {
        var configuration = ProviderConfiguration.defaultEnabled
        configuration.setFolderBookmark(Data("bookmark".utf8), for: .codex)

        XCTAssertEqual(configuration.setupState(for: .codex), .active)
    }

    func testClaudeExactCanBeActiveWithFolderAndCredential() {
        var configuration = ProviderConfiguration.defaultEnabled
        configuration.setFolderBookmark(Data("bookmark".utf8), for: .claudeCode)
        configuration.setClaudeExactEnabled(true)
        configuration.setClaudeCredentialImported(true)

        XCTAssertEqual(configuration.setupState(for: .claudeCode), .active)
    }

    func testOnboardingIsRequiredWhenAnyEnabledProviderNeedsSetup() {
        XCTAssertTrue(ProviderConfiguration.defaultEnabled.requiresOnboarding)
    }

    func testOnboardingIsCompleteWhenEnabledProvidersHaveRequiredFolders() {
        var configuration = ProviderConfiguration.defaultEnabled
        configuration.setFolderBookmark(Data("codex".utf8), for: .codex)
        configuration.setFolderBookmark(Data("claude".utf8), for: .claudeCode)

        XCTAssertFalse(configuration.requiresOnboarding)
    }

    func testFinishingOnboardingAllowsDashboardWithProvidersStillNeedingSetup() {
        var configuration = ProviderConfiguration.defaultEnabled

        configuration.markOnboardingCompleted()

        XCTAssertFalse(configuration.requiresOnboarding)
        XCTAssertEqual(configuration.setupState(for: .codex), .needsSetup)
        XCTAssertEqual(configuration.setupState(for: .claudeCode), .needsSetup)
    }

    func testDecodesConfigurationSavedBeforeOnboardingCompletionFlag() throws {
        let data = Data("""
        {
          "providers": [
            "Codex",
            {
              "mode": "enabled",
              "claudeExactEnabled": false,
              "claudeCredentialImported": false
            },
            "Claude Code",
            {
              "mode": "enabled",
              "claudeExactEnabled": false,
              "claudeCredentialImported": false
            }
          ]
        }
        """.utf8)

        let configuration = try JSONDecoder().decode(ProviderConfiguration.self, from: data)

        XCTAssertFalse(configuration.hasCompletedOnboarding)
        XCTAssertTrue(configuration.requiresOnboarding)
    }
}
