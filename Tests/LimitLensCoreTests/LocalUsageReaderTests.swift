import XCTest
@testable import LimitLensCore

final class LocalUsageReaderTests: XCTestCase {
    func testReadClaudeUsesOAuthUsageEndpointWhenTokenIsAvailable() async throws {
        let home = try temporaryHome()
        let now = ISO8601DateFormatter().date(from: "2026-05-17T20:00:00Z")!
        let expected = CLIUsageSnapshot(
            source: .claudeCode,
            health: .ok,
            summary: "Exact /usage",
            limits: [
                UsageLimitState(
                    id: "five_hour",
                    label: "Session courante",
                    usedPercent: 11,
                    resetDate: nil,
                    detail: "Fenêtre 5h"
                )
            ],
            metrics: [],
            lastUpdated: now,
            note: "Lu depuis le endpoint OAuth Claude Code."
        )
        let fetcher = FakeClaudeUsageFetcher(result: .success(expected))
        let reader = LocalUsageReader(
            homeDirectory: home,
            claudeOAuthStore: StaticClaudeOAuthStore(token: "oauth-token"),
            claudeUsageFetcher: fetcher
        )

        let snapshot = await reader.readClaude(now: now)

        XCTAssertEqual(snapshot, expected)
        XCTAssertEqual(fetcher.tokens, ["oauth-token"])
    }

    func testReadClaudeFallsBackToLocalUsageWhenOAuthTokenIsMissing() async throws {
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
        let reader = LocalUsageReader(
            homeDirectory: home,
            providerFolders: [.claudeCode: home.appendingPathComponent(".claude/projects")],
            claudeOAuthStore: StaticClaudeOAuthStore(token: nil),
            claudeUsageFetcher: FakeClaudeUsageFetcher(result: .failure(ProviderClientError.unauthorized))
        )

        let snapshot = await reader.readClaude(now: now)

        XCTAssertEqual(snapshot.health, .warning)
        XCTAssertEqual(snapshot.summary, "Estimation locale")
        XCTAssertEqual(snapshot.metrics.first { $0.id == "5h" }?.value, "1.4K tok")
    }

    func testReadClaudeReturnsUnavailableWhenOAuthAndLocalUsageAreMissing() async throws {
        let home = try temporaryHome()
        let reader = LocalUsageReader(
            homeDirectory: home,
            claudeOAuthStore: StaticClaudeOAuthStore(token: nil),
            claudeUsageFetcher: FakeClaudeUsageFetcher(result: .failure(ProviderClientError.unauthorized))
        )

        let snapshot = await reader.readClaude()

        XCTAssertEqual(snapshot.health, .unavailable)
        XCTAssertTrue(snapshot.note?.contains("Token OAuth Claude Code introuvable") == true)
    }

    func testUnavailableCodexSnapshotIncludesLocalScanDiagnostics() async throws {
        let home = try temporaryHome()
        let sessions = home.appendingPathComponent(".codex/sessions/2026/05/17")
        try FileManager.default.createDirectory(at: sessions, withIntermediateDirectories: true)
        try """
        {"timestamp":"2026-05-17T19:00:00Z","type":"event_msg","payload":{"type":"token_count"}}
        """.write(
            to: sessions.appendingPathComponent("rollout.jsonl"),
            atomically: true,
            encoding: .utf8
        )

        let snapshot = await LocalUsageReader(
            homeDirectory: home,
            providerFolders: [.codex: home.appendingPathComponent(".codex/sessions")]
        ).readCodex()

        XCTAssertEqual(snapshot.health, .unavailable)
        XCTAssertTrue(snapshot.note?.contains("1 fichier") == true)
        XCTAssertTrue(snapshot.note?.contains("1 ligne") == true)
    }

    func testReadCodexUsesConfiguredSessionsDirectory() async throws {
        let home = try temporaryHome()
        let sessions = home.appendingPathComponent("custom-codex")
        try FileManager.default.createDirectory(at: sessions, withIntermediateDirectories: true)
        try """
        {"timestamp":"2026-05-19T15:02:21.357Z","type":"event_msg","payload":{"type":"token_count","rate_limits":{"primary":{"used_percent":30.0,"window_minutes":300,"resets_at":1779203378},"secondary":{"used_percent":22.0,"window_minutes":10080,"resets_at":1779646918}}}}
        """.write(
            to: sessions.appendingPathComponent("session.jsonl"),
            atomically: true,
            encoding: .utf8
        )
        let reader = LocalUsageReader(
            homeDirectory: home,
            providerFolders: [.codex: sessions]
        )

        let snapshot = await reader.readCodex()

        XCTAssertEqual(snapshot.source, .codex)
        XCTAssertEqual(snapshot.limits.first?.usedPercent, 30)
    }

    func testReadCodexNeedsSetupWhenFolderMissing() async {
        let reader = LocalUsageReader(providerFolders: [:])

        let snapshot = await reader.readCodex()

        XCTAssertEqual(snapshot.health, .unavailable)
        XCTAssertTrue(snapshot.note?.contains("configur") == true)
    }

    func testCodexParserUsesLatestRateLimitEvent() {
        let lines = [
            """
            {"timestamp":"2026-05-17T18:00:00.123Z","type":"event_msg","payload":{"type":"token_count","rate_limits":{"primary":{"used_percent":25.0,"window_minutes":300,"resets_at":1770000000},"secondary":{"used_percent":70.0,"window_minutes":10080,"resets_at":1770500000},"credits":{"has_credits":false,"unlimited":false,"balance":null},"plan_type":"plus"}}}
            """,
            """
            {"timestamp":"2026-05-17T19:00:00.456Z","type":"event_msg","payload":{"type":"token_count","rate_limits":{"primary":{"used_percent":40.0,"window_minutes":300,"resets_at":1770000300},"secondary":{"used_percent":10.0,"window_minutes":10080,"resets_at":1770500300},"credits":{"has_credits":true,"unlimited":false,"balance":{"used":0.14,"limit":140.0}},"plan_type":"pro"}}}
            """
        ]

        let snapshot = CodexUsageParser.parse(lines: lines)

        XCTAssertEqual(snapshot?.source, .codex)
        XCTAssertEqual(snapshot?.limits.map(\.label), ["Session courante", "Semaine courante"])
        XCTAssertEqual(snapshot?.limits[0].usedPercent, 40)
        XCTAssertEqual(snapshot?.limits[1].usedPercent, 10)
        XCTAssertEqual(snapshot?.metrics.first?.value, "$0.14 / $140.00")
    }

    func testCodexParserReadsRateLimitsAtEventRoot() {
        let lines = [
            """
            {"timestamp":"2026-05-18T14:00:00.000Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"total_tokens":10}}},"rate_limits":{"primary":{"used_percent":15.0,"window_minutes":300,"resets_at":1778732235},"secondary":{"used_percent":32.0,"window_minutes":10080,"resets_at":1779145471},"credits":null,"plan_type":"prolite"}}
            """
        ]

        let snapshot = CodexUsageParser.parse(lines: lines)

        XCTAssertEqual(snapshot?.limits[0].usedPercent, 15)
        XCTAssertEqual(snapshot?.limits[1].usedPercent, 32)
    }

    func testCodexParserCombinesLatestRateLimitBucketsUsingMostConstrainedWindow() {
        let lines = [
            """
            {"timestamp":"2026-05-19T15:02:21.357Z","type":"event_msg","payload":{"type":"token_count","rate_limits":{"limit_id":"codex","limit_name":null,"primary":{"used_percent":30.0,"window_minutes":300,"resets_at":1779203378},"secondary":{"used_percent":22.0,"window_minutes":10080,"resets_at":1779646918},"credits":{"has_credits":false,"unlimited":false,"balance":null},"plan_type":"prolite"}}}
            """,
            """
            {"timestamp":"2026-05-19T15:02:37.578Z","type":"event_msg","payload":{"type":"token_count","rate_limits":{"limit_id":"codex_bengalfox","limit_name":"GPT-5.3-Codex-Spark","primary":{"used_percent":0.0,"window_minutes":300,"resets_at":1779220940},"secondary":{"used_percent":0.0,"window_minutes":10080,"resets_at":1779807740},"credits":{"has_credits":false,"unlimited":false,"balance":null},"plan_type":"prolite"}}}
            """
        ]

        let snapshot = CodexUsageParser.parse(lines: lines)

        XCTAssertEqual(snapshot?.limits[0].usedPercent, 30)
        XCTAssertEqual(snapshot?.limits[0].resetDate, Date(timeIntervalSince1970: 1_779_203_378))
        XCTAssertEqual(snapshot?.limits[1].usedPercent, 22)
        XCTAssertEqual(snapshot?.limits[1].resetDate, Date(timeIntervalSince1970: 1_779_646_918))
    }

    func testCodexParserUsesNewestTimestampWhenLinesAreOutOfOrder() {
        let lines = [
            """
            {"timestamp":"2026-05-17T21:56:21.000Z","type":"event_msg","payload":{"type":"token_count","rate_limits":{"primary":{"used_percent":2.0,"window_minutes":300,"resets_at":1779071104},"secondary":{"used_percent":93.0,"window_minutes":10080,"resets_at":1779145471}}}}
            """,
            """
            {"timestamp":"2026-05-17T19:00:00.000Z","type":"event_msg","payload":{"type":"token_count","rate_limits":{"primary":{"used_percent":53.0,"window_minutes":300,"resets_at":1779069300},"secondary":{"used_percent":22.0,"window_minutes":10080,"resets_at":1779069840}}}}
            """
        ]

        let snapshot = CodexUsageParser.parse(lines: lines)

        XCTAssertEqual(snapshot?.limits[0].usedPercent, 2)
        XCTAssertEqual(snapshot?.limits[1].usedPercent, 93)
    }

    func testClaudeParserAggregatesLocalUsageWindows() {
        let now = ISO8601DateFormatter().date(from: "2026-05-17T20:00:00Z")!
        let lines = [
            """
            {"timestamp":"2026-05-17T18:00:00.123Z","type":"assistant","message":{"model":"claude-sonnet-4-6","usage":{"input_tokens":100,"output_tokens":50,"cache_read_input_tokens":1000,"cache_creation_input_tokens":200}}}
            """,
            """
            {"timestamp":"2026-05-13T20:00:00.456Z","type":"assistant","message":{"model":"claude-opus-4-7","usage":{"input_tokens":500,"output_tokens":250,"cache_read_input_tokens":0,"cache_creation_input_tokens":0}}}
            """,
            """
            {"timestamp":"2026-05-01T20:00:00.789Z","type":"assistant","message":{"model":"claude-sonnet-4-6","usage":{"input_tokens":999,"output_tokens":999,"cache_read_input_tokens":999,"cache_creation_input_tokens":999}}}
            """
        ]

        let snapshot = ClaudeUsageParser.parse(lines: lines, now: now)

        XCTAssertEqual(snapshot?.source, .claudeCode)
        XCTAssertEqual(snapshot?.metrics.first { $0.id == "5h" }?.value, "1.4K tok")
        XCTAssertEqual(snapshot?.metrics.first { $0.id == "7d" }?.value, "2.1K tok")
        XCTAssertEqual(snapshot?.metrics.first { $0.id == "sonnet7d" }?.value, "1.4K tok")
        XCTAssertEqual(snapshot?.limits.first?.label, "Fenêtre 5h")
        XCTAssertNil(snapshot?.limits.first?.usedPercent)
    }

    private func temporaryHome() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("LimitLensTests")
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

private struct StaticClaudeOAuthStore: ClaudeOAuthStore {
    let token: String?

    func readAccessToken() async throws -> String? {
        token
    }
}

private final class FakeClaudeUsageFetcher: ClaudeUsageFetching {
    private(set) var tokens: [String] = []
    private let result: Result<CLIUsageSnapshot, Error>

    init(result: Result<CLIUsageSnapshot, Error>) {
        self.result = result
    }

    func fetchUsageSnapshot(oauthToken: String, now: Date) async throws -> CLIUsageSnapshot {
        tokens.append(oauthToken)
        return try result.get()
    }
}
