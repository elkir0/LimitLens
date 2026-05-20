import SwiftUI

/// Container hosting the menu bar popover. Flips in place between the dashboard
/// and the settings panel, and provides the frosted-glass background.
struct PopoverRootView: View {
    @EnvironmentObject private var appModel: LimitLensAppModel
    @State private var showingSettings = false

    var body: some View {
        Group {
            if showingSettings {
                SettingsView(onBack: { showingSettings = false })
            } else if appModel.configuration.requiresOnboarding {
                OnboardingView()
            } else {
                DashboardView(onOpenSettings: { showingSettings = true })
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showingSettings)
        .frame(width: 400)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.ultraThinMaterial)
                LinearGradient(
                    colors: [
                        .white.opacity(0.18),
                        .white.opacity(0.05),
                        .black.opacity(0.10)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(.white.opacity(0.22), lineWidth: 1)
            }
        }
    }
}
