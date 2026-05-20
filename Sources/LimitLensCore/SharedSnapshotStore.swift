import Foundation
#if canImport(Darwin)
import Darwin
#endif

/// Reads and writes the `SharedSnapshot` JSON used by the app and widget.
public struct SharedSnapshotStore {
    /// Legacy App Group identifier retained for signing configuration.
    public static let appGroupID = "group.com.limitlens.dashboard"
    /// `kind` string identifying the widget to `WidgetCenter`.
    public static let widgetKind = "LimitLensWidget"
    public static let claudeSmallWidgetKind = "LimitLensClaudeSmallV2Widget"
    public static let codexSmallWidgetKind = "LimitLensOpenAISmallV2Widget"
    public static let claudeMediumWidgetKind = "LimitLensClaudeMediumV2Widget"
    public static let codexMediumWidgetKind = "LimitLensOpenAIMediumV2Widget"
    public static let claudeLargeWidgetKind = "LimitLensClaudeLargeV2Widget"
    public static let codexLargeWidgetKind = "LimitLensOpenAILargeV2Widget"
    public static let overviewLargeWidgetKind = "LimitLensOverviewLargeV2Widget"

    public static let widgetKinds = [
        widgetKind,
        claudeSmallWidgetKind,
        codexSmallWidgetKind,
        claudeMediumWidgetKind,
        codexMediumWidgetKind,
        claudeLargeWidgetKind,
        codexLargeWidgetKind,
        overviewLargeWidgetKind
    ]

    private static let fileName = "snapshot.json"
    private static let supportDirectory = "Library/Application Support/LimitLens"

    private let directory: URL?

    /// Production initializer: uses the user's Application Support snapshot
    /// folder. The sandboxed app has a narrow read-write exception for this
    /// sanitized snapshot folder; the widget extension has read-only access.
    public init(
        fileManager: FileManager = .default
    ) {
        self.init(homeDirectory: Self.userHomeDirectory(
            fallback: fileManager.homeDirectoryForCurrentUser
        ))
    }

    /// Test initializer: uses an explicit directory.
    public init(directory: URL) {
        self.directory = directory
    }

    /// Test initializer: derives the production path from an explicit home.
    public init(homeDirectory: URL) {
        self.directory = homeDirectory.appendingPathComponent(Self.supportDirectory, isDirectory: true)
    }

    static func userHomeDirectory(
        fallback: URL,
        posixHomeDirectory: () -> URL? = Self.posixHomeDirectory
    ) -> URL {
        posixHomeDirectory() ?? fallback
    }

    private var fileURL: URL? {
        directory?.appendingPathComponent(Self.fileName)
    }

    /// Diagnostics: whether the shared directory resolved, and its path.
    public var isContainerAvailable: Bool { directory != nil }
    public var containerPath: String { directory?.path ?? "<nil>" }

    public var snapshotFileExists: Bool {
        guard let fileURL else { return false }
        return FileManager.default.fileExists(atPath: fileURL.path)
    }

    @discardableResult
    public func write(_ snapshot: SharedSnapshot) -> Bool {
        guard let fileURL else { return false }
        do {
            if let directory {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            }
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: fileURL, options: .atomic)
            return true
        } catch {
            return false
        }
    }

    /// Reads the last written snapshot, or `nil` when absent or unreadable.
    public func read() -> SharedSnapshot? {
        guard let fileURL, let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(SharedSnapshot.self, from: data)
    }

    private static func posixHomeDirectory() -> URL? {
        #if canImport(Darwin)
        guard
            let entry = getpwuid(getuid()),
            let home = entry.pointee.pw_dir
        else {
            return nil
        }
        return URL(fileURLWithPath: String(cString: home), isDirectory: true)
        #else
        return nil
        #endif
    }
}
