import LimitLensCore
import OSLog
import SwiftUI
import WidgetKit

private let widgetLog = Logger(subsystem: "com.limitlens.dashboard", category: "widget")

struct LimitLensEntry: TimelineEntry {
    let date: Date
    let snapshot: SharedSnapshot?
    let containerAvailable: Bool
}

struct LimitLensProvider: TimelineProvider {
    func placeholder(in context: Context) -> LimitLensEntry {
        return LimitLensEntry(date: Date(), snapshot: nil, containerAvailable: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (LimitLensEntry) -> Void) {
        completion(Self.makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LimitLensEntry>) -> Void) {
        let entry = Self.makeEntry()
        let nextRefresh = Date().addingTimeInterval(15 * 60)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }

    private static func makeEntry() -> LimitLensEntry {
        let store = SharedSnapshotStore()
        let snapshot = store.read()
        let diag = "container=\(store.isContainerAvailable) fileExists=\(store.snapshotFileExists) decoded=\(snapshot != nil) path=\(store.containerPath)"
        widgetLog.info("widget read: \(diag, privacy: .public)")
        return LimitLensEntry(date: Date(), snapshot: snapshot, containerAvailable: store.isContainerAvailable)
    }
}

struct LimitLensWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: SharedSnapshotStore.widgetKind, provider: LimitLensProvider()) { entry in
            LimitLensWidgetView(entry: entry)
        }
        .configurationDisplayName("LimitLens")
        .description("Usage restant de Claude Code et Codex.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct LimitLensClaudeSmallWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: SharedSnapshotStore.claudeSmallWidgetKind, provider: LimitLensProvider()) { entry in
            LimitLensWidgetView(entry: entry, mode: .provider(.claude))
        }
        .configurationDisplayName("LimitLens Claude petit")
        .description("Quota Claude Code en format compact.")
        .supportedFamilies([.systemSmall])
    }
}

struct LimitLensCodexSmallWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: SharedSnapshotStore.codexSmallWidgetKind, provider: LimitLensProvider()) { entry in
            LimitLensWidgetView(entry: entry, mode: .provider(.codex))
        }
        .configurationDisplayName("LimitLens OpenAI petit")
        .description("Quota OpenAI Codex en format compact.")
        .supportedFamilies([.systemSmall])
    }
}

struct LimitLensClaudeMediumWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: SharedSnapshotStore.claudeMediumWidgetKind, provider: LimitLensProvider()) { entry in
            LimitLensWidgetView(entry: entry, mode: .provider(.claude))
        }
        .configurationDisplayName("LimitLens Claude moyen")
        .description("Quotas Claude Code principaux.")
        .supportedFamilies([.systemMedium])
    }
}

struct LimitLensCodexMediumWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: SharedSnapshotStore.codexMediumWidgetKind, provider: LimitLensProvider()) { entry in
            LimitLensWidgetView(entry: entry, mode: .provider(.codex))
        }
        .configurationDisplayName("LimitLens OpenAI moyen")
        .description("Quotas OpenAI Codex principaux.")
        .supportedFamilies([.systemMedium])
    }
}

struct LimitLensClaudeLargeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: SharedSnapshotStore.claudeLargeWidgetKind, provider: LimitLensProvider()) { entry in
            LimitLensWidgetView(entry: entry, mode: .provider(.claude))
        }
        .configurationDisplayName("LimitLens Claude grand")
        .description("Vue detaillee des quotas Claude Code.")
        .supportedFamilies([.systemLarge])
    }
}

struct LimitLensCodexLargeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: SharedSnapshotStore.codexLargeWidgetKind, provider: LimitLensProvider()) { entry in
            LimitLensWidgetView(entry: entry, mode: .provider(.codex))
        }
        .configurationDisplayName("LimitLens OpenAI grand")
        .description("Vue detaillee des quotas OpenAI Codex.")
        .supportedFamilies([.systemLarge])
    }
}

struct LimitLensOverviewLargeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: SharedSnapshotStore.overviewLargeWidgetKind, provider: LimitLensProvider()) { entry in
            LimitLensWidgetView(entry: entry, mode: .overview)
        }
        .configurationDisplayName("LimitLens Vue d'ensemble")
        .description("Vue detaillee Claude Code et OpenAI Codex.")
        .supportedFamilies([.systemLarge])
    }
}
