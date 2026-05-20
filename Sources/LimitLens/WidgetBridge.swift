import LimitLensCore
import OSLog
import WidgetKit

/// Publishes the live provider snapshots into the shared snapshot file and asks
/// WidgetKit to reload the widget timeline.
enum WidgetBridge {
    private static let store = SharedSnapshotStore()
    private static let log = Logger(subsystem: "com.limitlens.dashboard", category: "widget")

    static func publish(_ snapshots: [CLIUsageSnapshot], configuration: ProviderConfiguration) {
        if !store.write(SharedSnapshot.from(snapshots: snapshots, configuration: configuration)) {
            log.error("Failed to write the shared snapshot.")
        }
        for kind in SharedSnapshotStore.widgetKinds {
            WidgetCenter.shared.reloadTimelines(ofKind: kind)
        }
    }
}
