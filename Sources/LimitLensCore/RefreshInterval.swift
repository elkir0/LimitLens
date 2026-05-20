import Foundation

public enum RefreshInterval: Int, CaseIterable, Identifiable, Sendable {
    case seconds30 = 30
    case seconds60 = 60
    case seconds120 = 120
    case minutes5 = 300
    case minutes10 = 600

    public static let userDefaultsKey = "refreshIntervalSeconds"
    public static let `default`: RefreshInterval = .seconds120

    public var id: Int { rawValue }
    public var seconds: TimeInterval { TimeInterval(rawValue) }

    public var displayLabel: String {
        switch self {
        case .seconds30:
            return "30 secondes"
        case .seconds60:
            return "60 secondes"
        case .seconds120:
            return "120 secondes"
        case .minutes5:
            return "5 minutes"
        case .minutes10:
            return "10 minutes"
        }
    }

    public var shortLabel: String {
        switch self {
        case .seconds30:
            return "30s"
        case .seconds60:
            return "60s"
        case .seconds120:
            return "120s"
        case .minutes5:
            return "5 min"
        case .minutes10:
            return "10 min"
        }
    }

    public static func resolved(rawValue: Int) -> RefreshInterval {
        RefreshInterval(rawValue: rawValue) ?? .default
    }
}
