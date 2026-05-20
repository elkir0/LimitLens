import XCTest
@testable import LimitLensCore

final class SharedSnapshotTests: XCTestCase {
    func testCodableRoundTrip() throws {
        let original = SharedSnapshot(
            generatedAt: Date(timeIntervalSince1970: 1_700_000_000),
            providers: [
                SharedSnapshot.Provider(
                    source: "Codex",
                    healthRawValue: "warning",
                    limits: [SharedSnapshot.Limit(label: "Semaine", remainingPercent: 15)]
                )
            ]
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SharedSnapshot.self, from: data)

        XCTAssertEqual(decoded, original)
    }

    func testDecodesLegacyProviderWithoutMetrics() throws {
        let data = """
        {
          "generatedAt": 1700000000,
          "providers": [
            {
              "source": "Codex",
              "healthRawValue": "ok",
              "limits": [
                {
                  "label": "Semaine",
                  "remainingPercent": 55
                }
              ]
            }
          ]
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(SharedSnapshot.self, from: data)

        XCTAssertEqual(decoded.providers[0].metrics, [])
        XCTAssertEqual(decoded.providers[0].setupState, .active)
        XCTAssertEqual(decoded.providers[0].remainingText, "55%")
    }

    func testInitFromLiveSnapshotsConvertsUtilizationToRemaining() {
        let live = CLIUsageSnapshot(
            source: .codex,
            health: .ok,
            summary: "x",
            limits: [
                UsageLimitState(id: "a", label: "Session", usedPercent: 40, resetDate: nil, detail: ""),
                UsageLimitState(
                    id: "b",
                    label: "Semaine courante",
                    usedPercent: nil,
                    resetDate: Date(timeIntervalSince1970: 1_779_646_918),
                    detail: "Fenêtre 1 sem."
                )
            ],
            metrics: [UsageMetric(id: "5h", title: "5h local", value: "1.4K tok")],
            lastUpdated: nil,
            note: nil
        )

        let shared = SharedSnapshot(from: [live], generatedAt: Date(timeIntervalSince1970: 0))

        XCTAssertEqual(shared.providers.count, 1)
        XCTAssertEqual(shared.providers[0].source, "Codex")
        XCTAssertEqual(shared.providers[0].healthRawValue, "ok")
        XCTAssertEqual(shared.providers[0].limits[0].remainingPercent, 60)
        XCTAssertNil(shared.providers[0].limits[1].remainingPercent)
        XCTAssertEqual(shared.providers[0].limits[1].resetDate, Date(timeIntervalSince1970: 1_779_646_918))
        XCTAssertEqual(shared.providers[0].limits[1].detail, "Fenêtre 1 sem.")
        XCTAssertEqual(shared.providers[0].weeklyResetText(timeZone: TimeZone(secondsFromGMT: -4 * 60 * 60)!), "dim. 24/05 14:21")
        XCTAssertEqual(shared.providers[0].remainingText, "60%")
        XCTAssertEqual(shared.providers[0].metrics[0].value, "1.4K tok")
        XCTAssertEqual(shared.providers[0].primaryMetricText, "1.4K tok 5h local")
    }

    func testGlobalAccessorsUseLowestRemainingAndWorstHealth() {
        let snapshot = SharedSnapshot(
            generatedAt: Date(timeIntervalSince1970: 0),
            providers: [
                SharedSnapshot.Provider(
                    source: "Claude Code",
                    healthRawValue: "ok",
                    limits: [SharedSnapshot.Limit(label: "5h", remainingPercent: 70)]
                ),
                SharedSnapshot.Provider(
                    source: "Codex",
                    healthRawValue: "warning",
                    limits: [SharedSnapshot.Limit(label: "Semaine", remainingPercent: 22)]
                )
            ]
        )

        XCTAssertEqual(snapshot.globalRemainingText, "22%")
        XCTAssertEqual(snapshot.globalHealth, .warning)
    }

    func testGlobalAccessorsAreNilAndUnavailableWithoutData() {
        let snapshot = SharedSnapshot(
            generatedAt: Date(timeIntervalSince1970: 0),
            providers: [
                SharedSnapshot.Provider(source: "Codex", healthRawValue: "unavailable", limits: [])
            ]
        )

        XCTAssertNil(snapshot.globalRemainingText)
        XCTAssertEqual(snapshot.globalHealth, .unavailable)
    }

    func testGlobalHealthFoldsInUtilizationWhenProviderHealthLags() {
        let snapshot = SharedSnapshot(
            generatedAt: Date(timeIntervalSince1970: 0),
            providers: [
                SharedSnapshot.Provider(
                    source: "Codex",
                    healthRawValue: "ok",
                    limits: [SharedSnapshot.Limit(label: "Semaine", remainingPercent: 2)]
                )
            ]
        )

        // 2% remaining = 98% used -> error, even though the provider reports "ok".
        XCTAssertEqual(snapshot.globalHealth, .error)
    }

    func testSharedSnapshotCarriesProviderSetupState() {
        var configuration = ProviderConfiguration.defaultEnabled
        configuration.setMode(.disabled, for: .claudeCode)
        configuration.setFolderBookmark(Data("codex".utf8), for: .codex)

        let snapshot = SharedSnapshot.from(
            snapshots: [snapshot(source: .codex, percent: 10)],
            configuration: configuration,
            generatedAt: Date(timeIntervalSince1970: 0)
        )

        XCTAssertEqual(snapshot.providers.first { $0.source == "Claude Code" }?.setupState, .disabled)
        XCTAssertEqual(snapshot.providers.first { $0.source == "Codex" }?.setupState, .active)
    }

    func testSharedSnapshotDoesNotEncodeProviderPathsOrSecrets() throws {
        let snapshot = SharedSnapshot.from(
            snapshots: [snapshot(source: .claudeCode, percent: 33)],
            configuration: .defaultEnabled,
            generatedAt: Date(timeIntervalSince1970: 0)
        )

        let json = String(data: try JSONEncoder().encode(snapshot), encoding: .utf8)!

        XCTAssertFalse(json.contains("/Users/"))
        XCTAssertFalse(json.localizedCaseInsensitiveContains("token"))
    }

    private func snapshot(source: CLIUsageSource, percent: Double) -> CLIUsageSnapshot {
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
