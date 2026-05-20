import XCTest
@testable import LimitLensCore

final class SharedSnapshotStoreTests: XCTestCase {
    func testWriteThenReadRoundTrips() throws {
        let store = SharedSnapshotStore(directory: try temporaryDirectory())
        let snapshot = SharedSnapshot(
            generatedAt: Date(timeIntervalSince1970: 1_700_000_000),
            providers: [
                SharedSnapshot.Provider(
                    source: "Codex",
                    healthRawValue: "ok",
                    limits: [SharedSnapshot.Limit(label: "Semaine", remainingPercent: 85)]
                )
            ]
        )

        XCTAssertTrue(store.write(snapshot))
        XCTAssertEqual(store.read(), snapshot)
    }

    func testWidgetKindsIncludeProviderSpecificWidgetsAndLegacyKind() {
        XCTAssertEqual(
            SharedSnapshotStore.widgetKinds,
            [
                "LimitLensWidget",
                "LimitLensClaudeSmallV2Widget",
                "LimitLensOpenAISmallV2Widget",
                "LimitLensClaudeMediumV2Widget",
                "LimitLensOpenAIMediumV2Widget",
                "LimitLensClaudeLargeV2Widget",
                "LimitLensOpenAILargeV2Widget",
                "LimitLensOverviewLargeV2Widget"
            ]
        )
    }

    func testHomeDirectoryStoreUsesApplicationSupportSnapshot() throws {
        let home = try temporaryDirectory()
        let store = SharedSnapshotStore(homeDirectory: home)
        let snapshot = SharedSnapshot(
            generatedAt: Date(timeIntervalSince1970: 1_700_000_100),
            providers: [
                SharedSnapshot.Provider(
                    source: "Claude Code",
                    healthRawValue: "warning",
                    limits: [SharedSnapshot.Limit(label: "Session", remainingPercent: 22)]
                )
            ]
        )

        XCTAssertTrue(store.write(snapshot))
        XCTAssertEqual(store.read(), snapshot)
        XCTAssertTrue(store.containerPath.hasSuffix("Library/Application Support/LimitLens"))
    }

    func testProductionHomeResolutionPrefersPOSIXHomeOverSandboxFallback() throws {
        let sandboxHome = URL(fileURLWithPath: "/Users/example/Library/Containers/com.limitlens.dashboard.widget/Data", isDirectory: true)
        let realHome = URL(fileURLWithPath: "/Users/example", isDirectory: true)

        let resolved = SharedSnapshotStore.userHomeDirectory(
            fallback: sandboxHome,
            posixHomeDirectory: { realHome }
        )

        XCTAssertEqual(resolved, realHome)
    }

    func testReadReturnsNilWhenNoSnapshotWritten() throws {
        let store = SharedSnapshotStore(directory: try temporaryDirectory())
        XCTAssertNil(store.read())
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("LimitLensSnapshotStoreTests")
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
