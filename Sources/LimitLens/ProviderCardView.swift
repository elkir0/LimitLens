import LimitLensCore
import SwiftUI

struct ProviderCardView: View {
    let snapshot: CLIUsageSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if snapshot.metrics.isEmpty && snapshot.limits.isEmpty {
                Text(snapshot.note ?? "Aucune donnée locale disponible.")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(spacing: 8) {
                    ForEach(snapshot.limits) { limit in
                        limitRow(limit)
                    }

                    if !snapshot.metrics.isEmpty {
                        HStack(spacing: 8) {
                            ForEach(snapshot.metrics.prefix(4)) { metric in
                                metricPill(metric.title, metric.value)
                            }
                        }
                    }
                }
            }

            if snapshot.health != .unavailable, let note = snapshot.note, !note.isEmpty {
                Text(note)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.white.opacity(0.10))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(.white.opacity(0.13), lineWidth: 1)
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(snapshot.health.color)
                .frame(width: 8, height: 8)
                .shadow(color: snapshot.health.color.opacity(0.45), radius: 5)

            Text(snapshot.source.rawValue)
                .font(.system(size: 14, weight: .semibold, design: .rounded))

            Spacer()

            Text(snapshot.summary)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(snapshot.health.color)
                .lineLimit(1)
        }
    }

    private func limitRow(_ limit: UsageLimitState) -> some View {
        let usedPercent = clampedPercent(limit.usedPercent)
        let displayPercent = displayPercent(for: usedPercent)

        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(limit.label)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer()

                Text(percentLabel(displayPercent))
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(displayPercent == nil ? .secondary : snapshot.health.color)
                    .lineLimit(1)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.black.opacity(0.16))

                    Capsule()
                        .fill(displayPercent == nil ? .white.opacity(0.18) : snapshot.health.color.opacity(0.88))
                        .frame(width: proxy.size.width * CGFloat((displayPercent ?? 18) / 100))
                }
            }
            .frame(height: 6)

            Text(limitSubtitle(limit))
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(9)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.black.opacity(0.08))
        }
    }

    private func metricPill(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(minWidth: 64, maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.black.opacity(0.10))
        }
    }

    private func clampedPercent(_ value: Double?) -> Double? {
        value.map { min(max($0, 0), 100) }
    }

    private func displayPercent(for usedPercent: Double?) -> Double? {
        guard let usedPercent else {
            return nil
        }
        return 100 - usedPercent
    }

    private func percentLabel(_ displayPercent: Double?) -> String {
        guard let displayPercent else {
            return "local"
        }
        let value = Int(displayPercent.rounded())
        return "\(value)% restant"
    }

    private func limitSubtitle(_ limit: UsageLimitState) -> String {
        guard let resetDate = limit.resetDate else {
            return limit.detail
        }
        let resetText = isWeeklyLimit(limit)
            ? MetricFormatter.weekdayDateTime(resetDate)
            : MetricFormatter.shortTime(resetDate)
        return "\(limit.detail) · réinit. \(resetText)"
    }

    private func isWeeklyLimit(_ limit: UsageLimitState) -> Bool {
        limit.label.localizedCaseInsensitiveContains("semaine")
            || limit.detail.localizedCaseInsensitiveContains("sem.")
            || limit.detail.localizedCaseInsensitiveContains("7j")
    }
}
