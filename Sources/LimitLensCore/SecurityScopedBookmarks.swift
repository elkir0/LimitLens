import Foundation

public protocol FolderBookmarkStore {
    func bookmarkData(for url: URL) throws -> Data
    func resolve(_ data: Data) throws -> ScopedFolderAccess
}

public struct ScopedFolderAccess {
    public let url: URL
    public let isStale: Bool

    private let startAccess: @Sendable () -> Bool
    private let stopAccess: @Sendable () -> Void

    public init(
        url: URL,
        isStale: Bool,
        startAccess: @escaping @Sendable () -> Bool,
        stopAccess: @escaping @Sendable () -> Void
    ) {
        self.url = url
        self.isStale = isStale
        self.startAccess = startAccess
        self.stopAccess = stopAccess
    }

    @discardableResult
    public func startAccessing() -> Bool {
        startAccess()
    }

    public func stopAccessing() {
        stopAccess()
    }
}

public struct SecurityScopedFolderBookmarkStore: FolderBookmarkStore {
    public init() {}

    public func bookmarkData(for url: URL) throws -> Data {
        try url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }

    public func resolve(_ data: Data) throws -> ScopedFolderAccess {
        var isStale = false
        let url = try URL(
            resolvingBookmarkData: data,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
        return ScopedFolderAccess(
            url: url,
            isStale: isStale,
            startAccess: { url.startAccessingSecurityScopedResource() },
            stopAccess: { url.stopAccessingSecurityScopedResource() }
        )
    }
}

public final class InMemoryFolderBookmarkStore: FolderBookmarkStore {
    private var urls: [Data: URL] = [:]

    public init() {}

    public func bookmarkData(for url: URL) throws -> Data {
        let data = Data(url.path.utf8)
        urls[data] = url
        return data
    }

    public func resolve(_ data: Data) throws -> ScopedFolderAccess {
        let url = urls[data] ?? URL(
            fileURLWithPath: String(decoding: data, as: UTF8.self),
            isDirectory: true
        )
        return ScopedFolderAccess(
            url: url,
            isStale: false,
            startAccess: { true },
            stopAccess: {}
        )
    }
}

public struct ProviderConfigurationStore {
    private let userDefaults: UserDefaults

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    public func load() throws -> ProviderConfiguration {
        guard let data = userDefaults.data(forKey: ProviderConfiguration.storageKey) else {
            return .defaultEnabled
        }
        return try JSONDecoder().decode(ProviderConfiguration.self, from: data)
    }

    public func save(_ configuration: ProviderConfiguration) throws {
        let data = try JSONEncoder().encode(configuration)
        userDefaults.set(data, forKey: ProviderConfiguration.storageKey)
    }
}
