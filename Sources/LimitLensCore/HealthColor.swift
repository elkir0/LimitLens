import SwiftUI

public extension CLIUsageHealth {
    /// Tint used across the app and the widget for this health state.
    var color: Color {
        switch self {
        case .ok:
            return Color(red: 0.20, green: 0.78, blue: 0.42)
        case .warning:
            return Color(red: 0.95, green: 0.66, blue: 0.20)
        case .error:
            return Color(red: 0.96, green: 0.23, blue: 0.24)
        case .unavailable:
            return Color(red: 0.58, green: 0.61, blue: 0.66)
        }
    }
}
