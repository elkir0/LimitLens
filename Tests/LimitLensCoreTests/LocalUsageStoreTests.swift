import XCTest
@testable import LimitLensCore

final class LocalUsageStoreTests: XCTestCase {
    @MainActor
    func testRefreshSkipsDisabledProviders() async {
        var configuration = ProviderConfiguration.defaultEnabled
        configuration.setMode(.disabled, for: .claudeCode)
        configuration.setFolderBookmark(Data("codex".utf8), for: .codex)
        let reader = StoreTestReader(
            codex: storeSnapshot(source: .codex, percent: 12),
            claude: storeSnapshot(source: .claudeCode, percent: 66)
        )
        let store = LocalUsageStore(
            reader: reader,
            configuration: configuration,
            userDefaults: isolatedDefaults()
        )

        await store.refresh()

        XCTAssertEqual(store.snapshots.map(\.source), [.codex])
        XCTAssertEqual(reader.claudeExactCalls, 0)
    }

    @MainActor
    func testRefreshUpdatesSnapshotsAndTimestamp() async throws {
        let claudeSnapshot = CLIUsageSnapshot(
            source: .claudeCode,
            health: .ok,
            summary: "Exact /usage",
            limits: [],
            metrics: [],
            lastUpdated: nil,
            note: nil
        )
        let reader = LocalUsageReader(
            homeDirectory: try temporaryHome(),
            claudeOAuthStore: StoreTestOAuthStore(token: "t"),
            claudeUsageFetcher: StoreTestUsageFetcher(snapshot: claudeSnapshot)
        )
        let store = LocalUsageStore(reader: reader, userDefaults: isolatedDefaults())
        let now = Date()

        await store.refresh(now: now)

        XCTAssertEqual(store.snapshots.first?.source, .claudeCode)
        XCTAssertEqual(store.snapshots.first?.summary, "Exact /usage")
        XCTAssertEqual(store.lastRefresh, now)
    }

    @MainActor
    func testRefreshKeepsCachedExactClaudeSnapshotWhenUsageEndpointRateLimits() async throws {
        let exactClaude = CLIUsageSnapshot(
            source: .claudeCode,
            health: .warning,
            summary: "Exact /usage",
            limits: [
                UsageLimitState(
                    id: "seven_day",
                    label: "Semaine courante",
                    usedPercent: 55,
                    resetDate: Date(timeIntervalSince1970: 1_779_646_918),
                    detail: "Fenêtre 1 sem."
                )
            ],
            metrics: [UsageMetric(id: "subscription", title: "Abonnement", value: "Max")],
            lastUpdated: Date(timeIntervalSince1970: 1_700_000_000),
            note: "Lu depuis le endpoint OAuth Claude Code."
        )
        let fetcher = StoreTestUsageFetcher(results: [
            .success(exactClaude),
            .failure(ProviderClientError.rateLimited(retryAfter: nil))
        ])
        let reader = LocalUsageReader(
            homeDirectory: try temporaryHome(),
            claudeOAuthStore: StoreTestOAuthStore(token: "t"),
            claudeUsageFetcher: fetcher
        )
        let store = LocalUsageStore(reader: reader, userDefaults: isolatedDefaults())

        await store.refresh(now: Date(timeIntervalSince1970: 1_700_000_100))
        await store.refresh(now: Date(timeIntervalSince1970: 1_700_000_200))

        let claude = store.snapshot(for: .claudeCode)
        XCTAssertEqual(claude.summary, "Exact /usage (cache)")
        XCTAssertEqual(claude.limits.first?.usedPercent, 55)
        XCTAssertTrue(claude.note?.contains("conservé") == true)
        XCTAssertEqual(fetcher.callCount, 2)
    }

    @MainActor
    func testRefreshSkipsClaudeUsageEndpointDuringRateLimitBackoff() async throws {
        let exactClaude = CLIUsageSnapshot(
            source: .claudeCode,
            health: .ok,
            summary: "Exact /usage",
            limits: [
                UsageLimitState(
                    id: "five_hour",
                    label: "Session courante",
                    usedPercent: 12,
                    resetDate: nil,
                    detail: "Fenêtre 5h"
                )
            ],
            metrics: [],
            lastUpdated: Date(timeIntervalSince1970: 1_700_000_000),
            note: "Lu depuis le endpoint OAuth Claude Code."
        )
        let fetcher = StoreTestUsageFetcher(results: [
            .success(exactClaude),
            .failure(ProviderClientError.rateLimited(retryAfter: nil)),
            .success(CLIUsageSnapshot.unavailable(source: .claudeCode, note: "Ne devrait pas être appelé."))
        ])
        let reader = LocalUsageReader(
            homeDirectory: try temporaryHome(),
            claudeOAuthStore: StoreTestOAuthStore(token: "t"),
            claudeUsageFetcher: fetcher
        )
        let store = LocalUsageStore(reader: reader, userDefaults: isolatedDefaults())

        await store.refresh(now: Date(timeIntervalSince1970: 1_700_000_000))
        await store.refresh(now: Date(timeIntervalSince1970: 1_700_000_060))
        await store.refresh(now: Date(timeIntervalSince1970: 1_700_000_120))

        XCTAssertEqual(fetcher.callCount, 2)
        XCTAssertEqual(store.snapshot(for: .claudeCode).limits.first?.usedPercent, 12)
    }

    @MainActor
    func testRateLimitedClaudeWithoutExactCacheFallsBackToLocalEstimate() async throws {
        let home = try temporaryHome()
        let projects = home.appendingPathComponent(".claude/projects/project")
        try FileManager.default.createDirectory(at: projects, withIntermediateDirectories: true)
        try """
        {"timestamp":"2026-05-17T18:00:00.123Z","type":"assistant","message":{"model":"claude-opus-4-7","usage":{"input_tokens":1000000,"output_tokens":500000,"cache_read_input_tokens":1000000,"cache_creation_input_tokens":200000}}}
        """.write(
            to: projects.appendingPathComponent("session.jsonl"),
            atomically: true,
            encoding: .utf8
        )
        let fetcher = StoreTestUsageFetcher(results: [
            .failure(ProviderClientError.rateLimited(retryAfter: nil))
        ])
        let reader = LocalUsageReader(
            homeDirectory: home,
            providerFolders: [.claudeCode: home.appendingPathComponent(".claude/projects")],
            claudeOAuthStore: StoreTestOAuthStore(token: "t"),
            claudeUsageFetcher: fetcher
        )
        let store = LocalUsageStore(reader: reader, userDefaults: isolatedDefaults())

        await store.refresh(now: ISO8601DateFormatter().date(from: "2026-05-17T20:00:00Z")!)

        let claude = store.snapshot(for: .claudeCode)
        XCTAssertEqual(claude.health, .warning)
        XCTAssertEqual(claude.summary, "Estimation locale")
        XCTAssertEqual(claude.metrics.first { $0.id == "5h" }?.value, "2.7M tok")
        XCTAssertTrue(claude.limits.allSatisfy { $0.usedPercent == nil })
        XCTAssertTrue(claude.note?.contains("estimation locale") == true)
    }

    @MainActor
    func testRateLimitedClaudeLocalFallbackShowsRetryTime() async throws {
        let home = try temporaryHome()
        let projects = home.appendingPathComponent(".claude/projects/project")
        try FileManager.default.createDirectory(at: projects, withIntermediateDirectories: true)
        try """
        {"timestamp":"2026-05-17T18:00:00.123Z","type":"assistant","message":{"model":"claude-opus-4-7","usage":{"input_tokens":100,"output_tokens":50,"cache_read_input_tokens":1000,"cache_creation_input_tokens":200}}}
        """.write(
            to: projects.appendingPathComponent("session.jsonl"),
            atomically: true,
            encoding: .utf8
        )
        let fetcher = StoreTestUsageFetcher(results: [
            .failure(ProviderClientError.rateLimited(retryAfter: "120"))
        ])
        let reader = LocalUsageReader(
            homeDirectory: home,
            providerFolders: [.claudeCode: home.appendingPathComponent(".claude/projects")],
            claudeOAuthStore: StoreTestOAuthStore(token: "t"),
            claudeUsageFetcher: fetcher
        )
        let store = LocalUsageStore(reader: reader, userDefaults: isolatedDefaults())
        let now = ISO8601DateFormatter().date(from: "2026-05-17T20:00:00Z")!

        await store.refresh(now: now)

        let claude = store.snapshot(for: .claudeCode)
        XCTAssertEqual(claude.summary, "Estimation locale")
        XCTAssertTrue(claude.note?.contains("jusqu'à \(MetricFormatter.shortTime(now.addingTimeInterval(120)))") == true)
    }

    @MainActor
    func testRefreshUsesLocalClaudeDuringRateLimitBackoffWithoutExactCache() async throws {
        let home = try temporaryHome()
        let projects = home.appendingPathComponent(".claude/projects/project")
        try FileManager.default.createDirectory(at: projects, withIntermediateDirectories: true)
        try """
        {"timestamp":"2026-05-17T18:00:00.123Z","type":"assistant","message":{"model":"claude-sonnet-4-6","usage":{"input_tokens":100,"output_tokens":50,"cache_read_input_tokens":1000,"cache_creation_input_tokens":200}}}
        """.write(
            to: projects.appendingPathComponent("session.jsonl"),
            atomically: true,
            encoding: .utf8
        )
        let now = ISO8601DateFormatter().date(from: "2026-05-17T20:00:00Z")!
        let defaults = isolatedDefaults()
        defaults.set(now.addingTimeInterval(900).timeIntervalSince1970, forKey: "LimitLens.claudeBackoffUntil")
        let fetcher = StoreTestUsageFetcher(results: [
            .success(CLIUsageSnapshot.unavailable(source: .claudeCode, note: "Ne devrait pas être appelé."))
        ])
        let reader = LocalUsageReader(
            homeDirectory: home,
            providerFolders: [.claudeCode: home.appendingPathComponent(".claude/projects")],
            claudeOAuthStore: StoreTestOAuthStore(token: "t"),
            claudeUsageFetcher: fetcher
        )
        let store = LocalUsageStore(reader: reader, userDefaults: defaults)

        await store.refresh(now: now)

        let claude = store.snapshot(for: .claudeCode)
        XCTAssertEqual(fetcher.callCount, 0)
        XCTAssertEqual(claude.summary, "Estimation locale")
        XCTAssertEqual(claude.metrics.first { $0.id == "5h" }?.value, "1.4K tok")
    }

    @MainActor
    func testRefreshIntervalIsPersistedAndReloaded() throws {
        let defaults = isolatedDefaults()
        let reader = LocalUsageReader(
            homeDirectory: try temporaryHome(),
            claudeOAuthStore: StoreTestOAuthStore(token: nil),
            claudeUsageFetcher: StoreTestUsageFetcher(snapshot: nil)
        )

        let store = LocalUsageStore(reader: reader, userDefaults: defaults)
        store.refreshInterval = .minutes5

        XCTAssertEqual(defaults.integer(forKey: RefreshInterval.userDefaultsKey), 300)

        let reloaded = LocalUsageStore(reader: reader, userDefaults: defaults)
        XCTAssertEqual(reloaded.refreshInterval, .minutes5)
    }

    private func isolatedDefaults() -> UserDefaults {
        UserDefaults(suiteName: "LimitLensStoreTests-\(UUID().uuidString)")!
    }

    private func temporaryHome() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("LimitLensStoreTests")
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func storeSnapshot(source: CLIUsageSource, percent: Double) -> CLIUsageSnapshot {
        CLIUsageSnapshot(
            source: source,
            health: .ok,
            summary: "Test",
            limits: [
                UsageLimitState(
                    id: "limit",
                    label: "Limit",
                    usedPercent: percent,
                    resetDate: nil,
                    detail: "Test"
                )
            ],
            metrics: [],
            lastUpdated: nil,
            note: nil
        )
    }
}

private struct StoreTestOAuthStore: ClaudeOAuthStore {
    let token: String?
    func readAccessToken() async throws -> String? { token }
}

private final class StoreTestUsageFetcher: ClaudeUsageFetching {
    private var results: [Result<CLIUsageSnapshot, Error>]
    private(set) var callCount = 0

    convenience init(snapshot: CLIUsageSnapshot?) {
        if let snapshot {
            self.init(results: [.success(snapshot)])
        } else {
            self.init(results: [.failure(ProviderClientError.unauthorized)])
        }
    }

    init(results: [Result<CLIUsageSnapshot, Error>]) {
        self.results = results
    }

    func fetchUsageSnapshot(oauthToken: String, now: Date) async throws -> CLIUsageSnapshot {
        callCount += 1
        guard !results.isEmpty else {
            throw ProviderClientError.unauthorized
        }
        return try results.removeFirst().get()
    }
}

private final class StoreTestReader: UsageReading {
    let codex: CLIUsageSnapshot
    let claude: CLIUsageSnapshot
    private(set) var claudeExactCalls = 0

    init(codex: CLIUsageSnapshot, claude: CLIUsageSnapshot) {
        self.codex = codex
        self.claude = claude
    }

    func readCodex() async -> CLIUsageSnapshot {
        codex
    }

    func readClaudeExact(now: Date) async throws -> CLIUsageSnapshot {
        claudeExactCalls += 1
        return claude
    }

    func readLocalClaude(now: Date) async -> CLIUsageSnapshot? {
        claude
    }
}
