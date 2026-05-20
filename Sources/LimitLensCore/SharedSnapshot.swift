import Foundation

/// Digested, `Codable` view of the provider usage, shared from the app to the
/// widget. Holds only what the widget renders.
public struct SharedSnapshot: Codable, Equatable, Sendable {
    public struct Limit: Codable, Equatable, Sendable {
        public let label: String
        /// Remaining percentage (100 - utilization), or `nil` when unknown.
        public let remainingPercent: Double?
        public let resetDate: Date?
        public let detail: String?

        private enum CodingKeys: String, CodingKey {
            case label
            case remainingPercent
            case resetDate
            case detail
        }

        public init(
            label: String,
            remainingPercent: Double?,
            resetDate: Date? = nil,
            detail: String? = nil
        ) {
            self.label = label
            self.remainingPercent = remainingPercent
            self.resetDate = resetDate
            self.detail = detail
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.label = try container.decode(String.self, forKey: .label)
            self.remainingPercent = try container.decodeIfPresent(Double.self, forKey: .remainingPercent)
            self.resetDate = try container.decodeIfPresent(Date.self, forKey: .resetDate)
            self.detail = try container.decodeIfPresent(String.self, forKey: .detail)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(label, forKey: .label)
            try container.encodeIfPresent(remainingPercent, forKey: .remainingPercent)
            try container.encodeIfPresent(resetDate, forKey: .resetDate)
            try container.encodeIfPresent(detail, forKey: .detail)
        }

        public var isWeeklyWindow: Bool {
            label.localizedCaseInsensitiveContains("semaine")
                || (detail?.localizedCaseInsensitiveContains("sem.") == true)
                || (detail?.localizedCaseInsensitiveContains("7j") == true)
        }
    }

    public struct Metric: Codable, Equatable, Sendable {
        public let title: String
        public let value: String

        public init(title: String, value: String) {
            self.title = title
            self.value = value
        }
    }

    public struct Provider: Codable, Equatable, Sendable {
        public let source: String
        public let healthRawValue: String
        public let setupStateRawValue: String
        public let limits: [Limit]
        public let metrics: [Metric]

        private enum CodingKeys: String, CodingKey {
            case source
            case healthRawValue
            case setupStateRawValue = "setupState"
            case limits
            case metrics
        }

        public init(
            source: String,
            healthRawValue: String,
            setupStateRawValue: String = ProviderSetupState.active.rawValue,
            limits: [Limit],
            metrics: [Metric] = []
        ) {
            self.source = source
            self.healthRawValue = healthRawValue
            self.setupStateRawValue = setupStateRawValue
            self.limits = limits
            self.metrics = metrics
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.source = try container.decode(String.self, forKey: .source)
            self.healthRawValue = try container.decode(String.self, forKey: .healthRawValue)
            self.setupStateRawValue = try container.decodeIfPresent(String.self, forKey: .setupStateRawValue)
                ?? ProviderSetupState.active.rawValue
            self.limits = try container.decode([Limit].self, forKey: .limits)
            self.metrics = try container.decodeIfPresent([Metric].self, forKey: .metrics) ?? []
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(source, forKey: .source)
            try container.encode(healthRawValue, forKey: .healthRawValue)
            try container.encode(setupStateRawValue, forKey: .setupStateRawValue)
            try container.encode(limits, forKey: .limits)
            try container.encode(metrics, forKey: .metrics)
        }

        public var health: CLIUsageHealth {
            CLIUsageHealth(rawValue: healthRawValue) ?? .unavailable
        }

        public var setupState: ProviderSetupState {
            ProviderSetupState(rawValue: setupStateRawValue) ?? .active
        }

        /// Lowest remaining percentage across this provider's limits.
        public var lowestRemainingPercent: Double? {
            limits.compactMap(\.remainingPercent).min()
        }

        public var remainingText: String? {
            lowestRemainingPercent.map { "\(Int($0.rounded()))%" }
        }

        public var primaryMetricText: String? {
            metrics.first.map { "\($0.value) \($0.title)" }
        }

        public func weeklyResetText(timeZone: TimeZone = .current) -> String? {
            let resetDate = limits
                .filter(\.isWeeklyWindow)
                .compactMap(\.resetDate)
                .min()
            return resetDate.map { MetricFormatter.weekdayDateTime($0, timeZone: timeZone) }
        }
    }

    public let generatedAt: Date
    public let providers: [Provider]

    public init(generatedAt: Date, providers: [Provider]) {
        self.generatedAt = generatedAt
        self.providers = providers
    }

    /// Builds a shared snapshot from the live provider snapshots.
    public init(from snapshots: [CLIUsageSnapshot], generatedAt: Date = Date()) {
        self.generatedAt = generatedAt
        self.providers = snapshots.map { snapshot in
            Self.provider(from: snapshot, setupState: .active)
        }
    }

    public static func from(
        snapshots: [CLIUsageSnapshot],
        configuration: ProviderConfiguration,
        generatedAt: Date = Date()
    ) -> SharedSnapshot {
        let snapshotsBySource = Dictionary(uniqueKeysWithValues: snapshots.map { ($0.source, $0) })
        let providers = CLIUsageSource.allCases.compactMap { source -> Provider? in
            guard configuration.providers[source] != nil else {
                return nil
            }
            let setupState = configuration.setupState(for: source)
            if let snapshot = snapshotsBySource[source] {
                return provider(from: snapshot, setupState: setupState)
            }
            return Provider(
                source: source.rawValue,
                healthRawValue: CLIUsageHealth.unavailable.rawValue,
                setupStateRawValue: setupState.rawValue,
                limits: [],
                metrics: []
            )
        }
        return SharedSnapshot(generatedAt: generatedAt, providers: providers)
    }

    private static func provider(
        from snapshot: CLIUsageSnapshot,
        setupState: ProviderSetupState
    ) -> Provider {
        Provider(
            source: snapshot.source.rawValue,
            healthRawValue: snapshot.health.rawValue,
            setupStateRawValue: setupState.rawValue,
            limits: snapshot.limits.map { limit in
                Limit(
                    label: limit.label,
                    remainingPercent: limit.usedPercent.map { min(max(100 - $0, 0), 100) },
                    resetDate: limit.resetDate,
                    detail: limit.detail
                )
            },
            metrics: snapshot.metrics.map { metric in
                Metric(title: metric.title, value: metric.value)
            }
        )
    }

    /// Lowest remaining percentage across every provider, formatted (e.g. "22%").
    public var globalRemainingText: String? {
        let remaining = activeProviders.flatMap(\.limits).compactMap(\.remainingPercent)
        guard let minRemaining = remaining.min() else { return nil }
        return "\(Int(minRemaining.rounded()))%"
    }

    /// Worst health across every provider. Like `MenuBarSummary`, this blends
    /// each provider's reported health with a utilization-derived health, so a
    /// provider whose reported health lags its usage is never shown as healthy.
    public var globalHealth: CLIUsageHealth {
        let providers = activeProviders
        let worstProviderHealth = providers.map(\.health).max { $0.severity < $1.severity } ?? .unavailable

        let remaining = providers.flatMap(\.limits).compactMap(\.remainingPercent)
        guard let minRemaining = remaining.min() else {
            return worstProviderHealth
        }

        let used = 100 - minRemaining
        let utilizationHealth: CLIUsageHealth
        if used >= 95 {
            utilizationHealth = .error
        } else if used >= 75 {
            utilizationHealth = .warning
        } else {
            utilizationHealth = .ok
        }

        return [worstProviderHealth, utilizationHealth]
            .max { $0.severity < $1.severity } ?? worstProviderHealth
    }

    private var activeProviders: [Provider] {
        providers.filter { $0.setupState != .disabled }
    }
}
