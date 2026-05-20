import LimitLensCore
import SwiftUI
import WidgetKit

enum LimitLensWidgetMode {
    case legacy
    case provider(WidgetProviderTarget)
    case overview
}

enum WidgetProviderTarget {
    case claude
    case codex

    var source: String {
        switch self {
        case .claude: "Claude Code"
        case .codex: "Codex"
        }
    }

    var displayName: String {
        switch self {
        case .claude: "Claude Code"
        case .codex: "OpenAI"
        }
    }
}

struct LimitLensWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: LimitLensEntry
    let mode: LimitLensWidgetMode

    init(entry: LimitLensEntry, mode: LimitLensWidgetMode = .legacy) {
        self.entry = entry
        self.mode = mode
    }

    var body: some View {
        content
            .containerBackground(.fill.tertiary, for: .widget)
    }

    @ViewBuilder
    private var content: some View {
        if let snapshot = entry.snapshot, !snapshot.providers.isEmpty {
            switch (family, mode) {
            case (.systemSmall, .provider(let target)):
                providerSmallView(provider(for: target, in: snapshot), displayName: target.displayName)
            case (.systemSmall, _):
                legacySmallView(snapshot)
            case (.systemMedium, .provider(let target)):
                providerMediumView(provider(for: target, in: snapshot), displayName: target.displayName)
            case (.systemMedium, _):
                overviewMediumView(snapshot)
            case (.systemLarge, .provider(let target)):
                providerLargeView(provider(for: target, in: snapshot), displayName: target.displayName)
            case (.systemLarge, _):
                overviewLargeView(snapshot)
            default:
                overviewMediumView(snapshot)
            }
        } else {
            emptyState
        }
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "gauge.medium")
                .font(.system(size: 22, weight: .semibold))
            Text(entry.containerAvailable ? "Aucune donnée\nOuvre LimitLens" : "Snapshot\nindisponible")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private func legacySmallView(_ snapshot: SharedSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            widgetTitle("LimitLens", size: 13)
            Spacer(minLength: 0)
            Text(snapshot.globalRemainingText ?? "--")
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .foregroundStyle(snapshot.globalHealth.color)
            Text("restant · \(MetricFormatter.shortTime(snapshot.generatedAt))")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func providerSmallView(_ provider: SharedSnapshot.Provider?, displayName: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            widgetTitle(displayName, size: 12)
            Spacer(minLength: 0)
            if let provider {
                if provider.hasDisplayData {
                    Text(provider.remainingText ?? "--")
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .foregroundStyle(provider.health.color)
                    Text(providerSmallSubtitle(provider))
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)
                } else {
                    providerSetupView(provider, compact: true)
                }
            } else {
                Text("--")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                Text("indisponible")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func overviewMediumView(_ snapshot: SharedSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            widgetTitle("LimitLens", size: 13)

            ForEach(overviewProviders(in: snapshot), id: \.source) { provider in
                providerRow(provider)
            }

            Spacer(minLength: 0)

            Text("Mis à jour à \(MetricFormatter.shortTime(snapshot.generatedAt))")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func providerMediumView(_ provider: SharedSnapshot.Provider?, displayName: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            widgetTitle(displayName, size: 13)

            if let provider, provider.hasDisplayData {
                ForEach(provider.limits.prefix(3), id: \.label) { limit in
                    limitRow(limit, health: provider.health, compact: true)
                }
            } else if let provider {
                providerSetupView(provider, compact: false)
            } else {
                unavailableProviderView
            }

            Spacer(minLength: 0)
            Text("Mis à jour à \(MetricFormatter.shortTime(entry.date))")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func providerLargeView(_ provider: SharedSnapshot.Provider?, displayName: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            widgetTitle(displayName, size: 14)

            if let provider, provider.hasDisplayData {
                HStack(alignment: .firstTextBaseline) {
                    Text(provider.remainingText ?? provider.primaryMetricText ?? "--")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(provider.health.color)
                    Text(provider.remainingText == nil ? "" : "restant")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                    Spacer()
                }

                VStack(spacing: 8) {
                    ForEach(provider.limits, id: \.label) { limit in
                        limitRow(limit, health: provider.health, compact: false)
                    }
                }

                if !provider.metrics.isEmpty {
                    metricGrid(provider.metrics)
                }
            } else if let provider {
                providerSetupView(provider, compact: false)
            } else {
                unavailableProviderView
            }

            Spacer(minLength: 0)
            Text("Mis à jour à \(MetricFormatter.shortTime(entry.date))")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func overviewLargeView(_ snapshot: SharedSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            widgetTitle("LimitLens", size: 14)

            HStack(alignment: .firstTextBaseline) {
                Text(snapshot.globalRemainingText ?? "--")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(snapshot.globalHealth.color)
                Text(snapshot.globalRemainingText == nil ? "" : "restant")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                Spacer()
            }

            ForEach(overviewProviders(in: snapshot), id: \.source) { provider in
                providerSection(provider)
            }

            Spacer(minLength: 0)
            Text("Mis à jour à \(MetricFormatter.shortTime(snapshot.generatedAt))")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func providerSection(_ provider: SharedSnapshot.Provider) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(displayName(for: provider))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                Spacer()
                Text(providerSummaryText(provider))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(provider.health.color)
            }

            if provider.hasDisplayData {
                ForEach(provider.limits.prefix(2), id: \.label) { limit in
                    limitRow(limit, health: provider.health, compact: true)
                }
            } else {
                Text(setupText(for: provider))
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func providerRow(_ provider: SharedSnapshot.Provider) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(displayName(for: provider))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                Spacer()
                Text(providerSummaryText(provider))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(provider.health.color)
            }

            if provider.hasDisplayData {
                progressBar(value: provider.lowestRemainingPercent, health: provider.health)
            }

            if let weeklyReset = provider.weeklyResetText() {
                Text("Semaine · \(weeklyReset)")
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
    }

    private func limitRow(_ limit: SharedSnapshot.Limit, health: CLIUsageHealth, compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: compact ? 3 : 5) {
            HStack {
                Text(limit.label)
                    .font(.system(size: compact ? 10 : 11, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                Spacer()
                Text(limit.remainingPercent.map { "\(Int($0.rounded()))% restant" } ?? "local")
                    .font(.system(size: compact ? 10 : 11, weight: .bold, design: .rounded))
                    .foregroundStyle(limit.remainingPercent == nil ? .secondary : health.color)
                    .lineLimit(1)
            }
            progressBar(value: limit.remainingPercent, health: health)
            if !compact, let resetDate = limit.resetDate {
                Text("réinit. \(resetText(for: limit, resetDate: resetDate))")
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private func progressBar(value: Double?, health: CLIUsageHealth) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(.black.opacity(0.16))
                Capsule()
                    .fill((value == nil ? Color.secondary : health.color).opacity(0.88))
                    .frame(width: proxy.size.width * CGFloat((value ?? 18) / 100))
            }
        }
        .frame(height: 6)
    }

    private func metricGrid(_ metrics: [SharedSnapshot.Metric]) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 8) {
            ForEach(metrics.prefix(4), id: \.title) { metric in
                VStack(alignment: .leading, spacing: 2) {
                    Text(metric.title.uppercased())
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                    Text(metric.value)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
            }
        }
    }

    private var unavailableProviderView: some View {
        Text("indisponible")
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(.secondary)
    }

    private func providerSetupView(_ provider: SharedSnapshot.Provider, compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: compact ? 3 : 6) {
            Text(setupTitle(for: provider))
                .font(.system(size: compact ? 12 : 14, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
            Text(setupText(for: provider))
                .font(.system(size: compact ? 10 : 12, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
        }
    }

    private func widgetTitle(_ title: String, size: CGFloat) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "gauge.medium")
                .font(.system(size: size, weight: .semibold))
            Text(title)
                .font(.system(size: size, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .foregroundStyle(.secondary)
    }

    private func provider(for target: WidgetProviderTarget, in snapshot: SharedSnapshot) -> SharedSnapshot.Provider? {
        snapshot.providers.first { $0.source == target.source }
    }

    private func overviewProviders(in snapshot: SharedSnapshot) -> [SharedSnapshot.Provider] {
        snapshot.providers.filter { $0.setupState != .disabled }
    }

    private func displayName(for provider: SharedSnapshot.Provider) -> String {
        provider.source == "Codex" ? "OpenAI" : provider.source
    }

    private func providerSmallSubtitle(_ provider: SharedSnapshot.Provider) -> String {
        if let weeklyReset = provider.weeklyResetText() {
            return "Semaine · \(weeklyReset)"
        }
        return "restant · \(MetricFormatter.shortTime(entry.date))"
    }

    private func providerSummaryText(_ provider: SharedSnapshot.Provider) -> String {
        guard provider.hasDisplayData else {
            return setupTitle(for: provider)
        }
        return provider.remainingText.map { "\($0) restant" } ?? provider.primaryMetricText ?? "indisponible"
    }

    private func setupTitle(for provider: SharedSnapshot.Provider) -> String {
        switch provider.setupState {
        case .disabled:
            String(localized: "widget.disabled")
        case .needsSetup:
            String(localized: "widget.setupRequired")
        case .active, .degraded, .error:
            String(localized: "widget.setupRequired")
        }
    }

    private func setupText(for provider: SharedSnapshot.Provider) -> String {
        switch provider.setupState {
        case .disabled:
            String(localized: "widget.disabled")
        case .needsSetup, .active, .degraded, .error:
            String(localized: "widget.openLimitLens")
        }
    }

    private func resetText(for limit: SharedSnapshot.Limit, resetDate: Date) -> String {
        if limit.isWeeklyWindow {
            return MetricFormatter.weekdayDateTime(resetDate)
        }
        return MetricFormatter.shortTime(resetDate)
    }
}

private extension SharedSnapshot.Provider {
    var hasDisplayData: Bool {
        setupState != .disabled && (!limits.isEmpty || !metrics.isEmpty)
    }
}
