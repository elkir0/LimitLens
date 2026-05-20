import Foundation

public enum MetricFormatter {
    public static func currencyUSD(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.currencySymbol = "$"
        formatter.positiveFormat = "¤#,##0.00"
        formatter.negativeFormat = "-¤#,##0.00"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: value as NSDecimalNumber) ?? "$0.00"
    }

    public static func compactInteger(_ value: Int) -> String {
        let absolute = abs(value)
        let sign = value < 0 ? "-" : ""

        switch absolute {
        case 1_000_000...:
            return sign + compact(Double(absolute) / 1_000_000, suffix: "M")
        case 1_000...:
            return sign + compact(Double(absolute) / 1_000, suffix: "K")
        default:
            return "\(value)"
        }
    }

    public static func tokens(_ value: Int) -> String {
        "\(compactInteger(value)) tok"
    }

    public static func shortTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }

    public static func weekdayDateTime(
        _ date: Date,
        timeZone: TimeZone = .current
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.timeZone = timeZone
        formatter.dateFormat = "EEE dd/MM HH:mm"
        return formatter.string(from: date)
    }

    private static func compact(_ value: Double, suffix: String) -> String {
        if value >= 10 {
            return "\(Int(value.rounded()))\(suffix)"
        }

        let rounded = (value * 10).rounded() / 10
        if rounded.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(rounded))\(suffix)"
        }
        return String(format: "%.1f%@", rounded, suffix)
    }
}
