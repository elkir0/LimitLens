import Foundation

public struct APIQueryRange: Equatable, Sendable {
    public let start: Date
    public let end: Date

    public var startUnixSeconds: Int {
        Int(start.timeIntervalSince1970)
    }

    public var endUnixSeconds: Int {
        Int(end.timeIntervalSince1970)
    }

    public var startRFC3339: String {
        Self.rfc3339Formatter.string(from: start)
    }

    public var endRFC3339: String {
        Self.rfc3339Formatter.string(from: end)
    }

    public static func monthToDate(now: Date = Date()) -> APIQueryRange {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let components = calendar.dateComponents([.year, .month], from: now)
        let start = calendar.date(from: components) ?? now
        return APIQueryRange(start: start, end: now)
    }

    private static let rfc3339Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}
