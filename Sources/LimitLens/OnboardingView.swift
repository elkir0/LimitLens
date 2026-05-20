import LimitLensCore
import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var appModel: LimitLensAppModel
    @State private var step = 0
    @State private var folderError: String?

    private let folderPicker = FolderPermissionPicker()

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header

            switch step {
            case 0:
                welcomeStep
            case 1:
                providersStep
            case 2:
                foldersStep
            case 3:
                claudeExactStep
            default:
                summaryStep
            }

            if let folderError {
                Text(folderError)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(CLIUsageHealth.error.color)
            }

            if let message = appModel.setupMessage {
                Text(message)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            navigation
        }
        .padding(20)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("LimitLens")
                .font(.system(size: 22, weight: .semibold, design: .rounded))
            Text(String(localized: "setup.subtitle"))
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(String(localized: "setup.welcome.title"))
                .font(.system(size: 16, weight: .semibold, design: .rounded))
            Text(String(localized: "setup.welcome.body"))
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var providersStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            providerToggle(.codex, title: String(localized: "provider.openai.name"))
            providerToggle(.claudeCode, title: String(localized: "provider.claude.name"))
        }
    }

    private var foldersStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            if appModel.configuration.providers[.codex]?.mode == .enabled {
                folderRow(
                    source: .codex,
                    title: String(localized: "setup.chooseCodexFolder"),
                    hint: "~/.codex/sessions"
                )
            }
            if appModel.configuration.providers[.claudeCode]?.mode == .enabled {
                folderRow(
                    source: .claudeCode,
                    title: String(localized: "setup.chooseClaudeFolder"),
                    hint: "~/.claude/projects"
                )
            }
        }
    }

    private var claudeExactStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "setup.importClaude.explanation"))
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                Task { await appModel.importClaudeCredentials() }
            } label: {
                Label(String(localized: "setup.importClaude"), systemImage: "key")
            }
            .disabled(appModel.configuration.providers[.claudeCode]?.mode == .disabled)
        }
    }

    private var summaryStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            setupSummary(.codex, title: String(localized: "provider.openai.name"))
            setupSummary(.claudeCode, title: String(localized: "provider.claude.name"))
            Text(String(localized: "setup.summary.body"))
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var navigation: some View {
        HStack {
            Button(String(localized: "setup.back")) {
                step = max(step - 1, 0)
            }
            .disabled(step == 0)

            Spacer()

            Button(step >= 4 ? String(localized: "setup.finish") : String(localized: "setup.next")) {
                if step >= 4 {
                    appModel.finishOnboarding()
                } else {
                    step += 1
                }
            }
            .keyboardShortcut(.defaultAction)
        }
    }

    private func providerToggle(_ source: CLIUsageSource, title: String) -> some View {
        Toggle(isOn: Binding(
            get: { appModel.configuration.providers[source]?.mode == .enabled },
            set: { appModel.setProvider(source, enabled: $0) }
        )) {
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
        }
        .toggleStyle(.switch)
    }

    private func folderRow(source: CLIUsageSource, title: String, hint: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                Text(hint)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(String(localized: "setup.choose")) {
                Task {
                    await chooseFolder(source: source, prompt: title)
                }
            }
        }
        .padding(10)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.white.opacity(0.09))
        }
    }

    private func setupSummary(_ source: CLIUsageSource, title: String) -> some View {
        let state = appModel.configuration.setupState(for: source)
        return HStack {
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
            Spacer()
            Text(label(for: state))
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(color(for: state))
        }
    }

    private func chooseFolder(source: CLIUsageSource, prompt: String) async {
        do {
            if let bookmark = try await folderPicker.pickFolder(
                prompt: prompt,
                defaultURL: defaultFolder(for: source)
            ) {
                appModel.saveFolderBookmark(bookmark, for: source)
                folderError = nil
            }
        } catch {
            folderError = String(localized: "setup.folder.failure")
        }
    }

    private func defaultFolder(for source: CLIUsageSource) -> URL {
        switch source {
        case .codex:
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex/sessions")
        case .claudeCode:
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude/projects")
        }
    }

    private func label(for state: ProviderSetupState) -> String {
        switch state {
        case .disabled: String(localized: "setup.state.disabled")
        case .needsSetup: String(localized: "setup.state.needsSetup")
        case .active: String(localized: "setup.state.active")
        case .degraded: String(localized: "setup.state.degraded")
        case .error: String(localized: "setup.state.error")
        }
    }

    private func color(for state: ProviderSetupState) -> Color {
        switch state {
        case .disabled, .needsSetup:
            return .secondary
        case .active:
            return CLIUsageHealth.ok.color
        case .degraded:
            return CLIUsageHealth.warning.color
        case .error:
            return CLIUsageHealth.error.color
        }
    }
}
