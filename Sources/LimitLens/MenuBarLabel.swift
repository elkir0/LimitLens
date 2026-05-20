import LimitLensCore
import SwiftUI

/// The always-visible menu bar content: a gauge icon plus the lowest remaining
/// percentage, both tinted by the worst provider health. Owns the lifetime of
/// the store's auto-refresh loop, since this view lives as long as the app, and
/// publishes each refresh to the widget.
struct MenuBarLabel: View {
    @ObservedObject var store: LocalUsageStore

    var body: some View {
        let summary = MenuBarSummary.make(from: store.snapshots)
        HStack(spacing: 3) {
            Image(systemName: "gauge.medium")
            if let remaining = summary.remainingText {
                Text(remaining)
            }
        }
        .foregroundStyle(summary.health.color)
        .task {
            await store.startAutoRefresh()
        }
        .onChange(of: store.snapshots) {
            guard store.lastRefresh != nil else {
                return
            }
            WidgetBridge.publish(store.snapshots, configuration: store.configuration)
        }
    }
}
