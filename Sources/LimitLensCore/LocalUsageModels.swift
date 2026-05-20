import Foundation

public enum CLIUsageSource: String, CaseIterable, Codable, Identifiable, Sendable {
    case claudeCode = "Claude Code"
    case codex = "Codex"

    public var id: String { rawValue }
}

public enum CLIUsageHealth: String, Codable, Equatable, Sendable {
    case ok
    case warning
    case error
    case unavailable

    public var severity: Int {
        switch self {
        case .ok: 0
        case .unavailable: 1
        case .warning: 2
        case .error: 3
        }
    }
}

public struct UsageLimitState: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let label: String
    public let usedPercent: Double?
    public let resetDate: Date?
    public let detail: String

    public init(id: String, label: String, usedPercent: Double?, resetDate: Date?, detail: String) {
        self.id = id
        self.label = label
        self.usedPercent = usedPercent
        self.resetDate = resetDate
        self.detail = detail
    }
}

public struct CLIUsageSnapshot: Codable, Equatable, Identifiable, Sendable {
    public var id: CLIUsageSource { source }
    public let source: CLIUsageSource
    public let health: CLIUsageHealth
    public let summary: String
    public let limits: [UsageLimitState]
    public let metrics: [UsageMetric]
    public let lastUpdated: Date?
    public let note: String?

    public init(
        source: CLIUsageSource,
        health: CLIUsageHealth,
        summary: String,
        limits: [UsageLimitState],
        metrics: [UsageMetric],
        lastUpdated: Date?,
        note: String?
    ) {
        self.source = source
        self.health = health
        self.summary = summary
        self.limits = limits
        self.metrics = metrics
        self.lastUpdated = lastUpdated
        self.note = note
    }

    public static func unavailable(source: CLIUsageSource, note: String) -> CLIUsageSnapshot {
        CLIUsageSnapshot(
            source: source,
            health: .unavailable,
            summary: "Aucune donnée",
            limits: [],
            metrics: [],
            lastUpdated: nil,
            note: note
        )
    }
}
