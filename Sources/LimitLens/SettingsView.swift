import LimitLensCore
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appModel: LimitLensAppModel
    @EnvironmentObject private var store: LocalUsageStore
    let onBack: () -> Void

    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var launchAtLoginError: String?
    @State private var providerError: String?

    private let folderPicker = FolderPermissionPicker()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Retour")

                Text("Réglages")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                Spacer()
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Mise à jour")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))

                HStack {
                    Text("Délai")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Picker("Délai", selection: $store.refreshInterval) {
                        ForEach(RefreshInterval.allCases) { interval in
                            Text(interval.displayLabel).tag(interval)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(width: 160)
                }

                Toggle(isOn: launchAtLoginBinding) {
                    Text("Démarrer à l'ouverture de session")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                }
                .toggleStyle(.switch)

                if let launchAtLoginError {
                    Text(launchAtLoginError)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(CLIUsageHealth.error.color)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(12)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.white.opacity(0.09))
            }

            VStack(alignment: .leading, spacing: 12) {
                providerSettingsRow(
                    source: .codex,
                    title: String(localized: "provider.openai.name"),
                    path: "~/.codex/sessions",
                    detail: String(localized: "settings.codex.detail")
                )

                providerSettingsRow(
                    source: .claudeCode,
                    title: String(localized: "provider.claude.name"),
                    path: "~/.claude/projects + Keychain",
                    detail: String(localized: "settings.claude.detail")
                )
            }

            if let providerError {
                Text(providerError)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(CLIUsageHealth.error.color)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let setupMessage = appModel.setupMessage {
                Text(setupMessage)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(String(localized: "settings.privacy.summary"))
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { launchAtLogin },
            set: { newValue in
                do {
                    try LaunchAtLogin.setEnabled(newValue)
                    launchAtLoginError = nil
                } catch {
                    launchAtLoginError = "Impossible de modifier le démarrage automatique : \(error.localizedDescription)"
                }
                launchAtLogin = LaunchAtLogin.isEnabled
            }
        )
    }

    private func providerSettingsRow(source: CLIUsageSource, title: String, path: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Toggle(isOn: Binding(
                    get: { appModel.configuration.providers[source]?.mode == .enabled },
                    set: { appModel.setProvider(source, enabled: $0) }
                )) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                }
                .toggleStyle(.switch)

                Spacer()
                Label(statusLabel(for: appModel.configuration.setupState(for: source)), systemImage: "internaldrive")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            Text(path)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Text(detail)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Button(String(localized: "setup.choose")) {
                    Task {
                        await chooseFolder(source: source, prompt: title)
                    }
                }
                .disabled(appModel.configuration.providers[source]?.mode == .disabled)

                if source == .claudeCode {
                    Button(String(localized: "setup.importClaude")) {
                        Task { await appModel.importClaudeCredentials() }
                    }
                    .disabled(appModel.configuration.providers[source]?.mode == .disabled)
                }

                Button(String(localized: "settings.resetProvider")) {
                    appModel.resetProvider(source)
                }
                .disabled(appModel.configuration.providers[source]?.mode == .disabled)
            }
            .font(.system(size: 11, weight: .semibold, design: .rounded))
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.white.opacity(0.09))
        }
    }

    private func chooseFolder(source: CLIUsageSource, prompt: String) async {
        do {
            if let bookmark = try await folderPicker.pickFolder(
                prompt: prompt,
                defaultURL: defaultFolder(for: source)
            ) {
                appModel.saveFolderBookmark(bookmark, for: source)
                providerError = nil
            }
        } catch {
            providerError = String(localized: "setup.folder.failure")
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

    private func statusLabel(for state: ProviderSetupState) -> String {
        switch state {
        case .disabled:
            String(localized: "setup.state.disabled")
        case .needsSetup:
            String(localized: "setup.state.needsSetup")
        case .active:
            String(localized: "setup.state.active")
        case .degraded:
            String(localized: "setup.state.degraded")
        case .error:
            String(localized: "setup.state.error")
        }
    }
}
