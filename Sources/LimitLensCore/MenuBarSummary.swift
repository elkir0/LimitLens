import Foundation

/// Glanceable summary derived from the provider snapshots, shown in the menu bar.
public struct MenuBarSummary: Equatable, Sendable {
    /// Lowest remaining percentage across all limits, formatted (e.g. "67%").
    /// `nil` when no usable limit is available.
    public let remainingText: String?
    /// Worst health across providers; drives the tint.
    public let health: CLIUsageHealth

    public init(remainingText: String?, health: CLIUsageHealth) {
        self.remainingText = remainingText
        self.health = health
    }

    /// Builds the summary from provider snapshots: takes the highest utilization
    /// across every limit (the most alarming) and converts it to remaining percent.
    /// Limits without a utilization value are ignored.
    ///
    /// The health is the worst of the utilization-derived health and each
    /// provider's own snapshot health, so a failed provider (e.g. an unavailable
    /// snapshot) is never hidden behind a healthy tint from the other provider.
    public static func make(from snapshots: [CLIUsageSnapshot]) -> MenuBarSummary {
        let usedPercents = snapshots
            .flatMap(\.limits)
            .compactMap(\.usedPercent)
        let worstSnapshotHealth = snapshots
            .map(\.health)
            .max { $0.severity < $1.severity } ?? .unavailable

        guard let maxUsed = usedPercents.max() else {
            return MenuBarSummary(remainingText: nil, health: worstSnapshotHealth)
        }

        let remaining = min(max(100 - maxUsed, 0), 100)
        let utilizationHealth: CLIUsageHealth
        if maxUsed >= 95 {
            utilizationHealth = .error
        } else if maxUsed >= 75 {
            utilizationHealth = .warning
        } else {
            utilizationHealth = .ok
        }
        let health = [utilizationHealth, worstSnapshotHealth]
            .max { $0.severity < $1.severity } ?? utilizationHealth

        return MenuBarSummary(
            remainingText: "\(Int(remaining.rounded()))%",
            health: health
        )
    }
}
