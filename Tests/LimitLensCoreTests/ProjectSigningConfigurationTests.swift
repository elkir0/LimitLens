import XCTest

final class ProjectSigningConfigurationTests: XCTestCase {
    func testMainAppIsSandboxedForPublicDistribution() throws {
        let entitlements = try readPlist("Sources/LimitLens/LimitLens.entitlements")

        XCTAssertEqual(entitlements["com.apple.security.app-sandbox"] as? Bool, true)
        XCTAssertEqual(entitlements["com.apple.security.files.user-selected.read-only"] as? Bool, true)
        XCTAssertEqual(entitlements["com.apple.security.files.bookmarks.app-scope"] as? Bool, true)
        XCTAssertEqual(entitlements["com.apple.security.network.client"] as? Bool, true)
    }

    func testFolderPickerCanReachHiddenProviderDirectories() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let picker = try String(
            contentsOf: root.appendingPathComponent("Sources/LimitLens/FolderPermissionPicker.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(picker.contains("panel.showsHiddenFiles = true"))
        XCTAssertTrue(picker.contains("NSApp.activate(ignoringOtherApps: true)"))
        XCTAssertTrue(picker.contains("NSApp.setActivationPolicy(.regular)"))
        XCTAssertTrue(picker.contains("panel.begin"))
        XCTAssertFalse(picker.contains("runModal()"))
    }

    func testSettingsViewDisplaysProviderSetupMessages() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let settings = try String(
            contentsOf: root.appendingPathComponent("Sources/LimitLens/SettingsView.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(settings.contains("appModel.setupMessage"))
        XCTAssertTrue(settings.contains("setupMessage"))
    }

    func testWidgetViewDisplaysProviderStatusMessages() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let widgetView = try String(
            contentsOf: root.appendingPathComponent("Sources/LimitLensWidget/LimitLensWidgetView.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(widgetView.contains("provider.note"))
        XCTAssertTrue(widgetView.contains("provider.summary"))
        XCTAssertTrue(widgetView.contains("providerStatusLine"))
    }

    func testMainAppCanWriteSanitizedApplicationSupportSnapshot() throws {
        let entitlements = try readPlist("Sources/LimitLens/LimitLens.entitlements")
        let snapshotPaths = entitlements[
            "com.apple.security.temporary-exception.files.home-relative-path.read-write"
        ] as? [String]

        XCTAssertEqual(snapshotPaths, ["/Library/Application Support/LimitLens/"])
    }

    func testHardenedRuntimeEnabledForReleaseTargets() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let projectSpec = try String(
            contentsOf: root.appendingPathComponent("project.yml"),
            encoding: .utf8
        )

        XCTAssertTrue(projectSpec.contains("ENABLE_HARDENED_RUNTIME: YES"))
    }

    func testPublicProjectDoesNotHardcodePersonalDevelopmentTeam() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let projectSpec = try String(
            contentsOf: root.appendingPathComponent("project.yml"),
            encoding: .utf8
        )

        XCTAssertNil(
            projectSpec.range(
                of: #"DEVELOPMENT_TEAM:\s*[A-Z0-9]{10}"#,
                options: .regularExpression
            )
        )
    }

    func testXcodegenGenerationPreservesAppGroupCapability() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let projectSpec = try String(
            contentsOf: root.appendingPathComponent("project.yml"),
            encoding: .utf8
        )

        XCTAssertTrue(
            projectSpec.contains("postGenCommand: bash Scripts/ensure-app-group-capability.sh"),
            "XcodeGen must run the App Groups capability patch after regenerating the project."
        )

        let patchScript = try String(
            contentsOf: root.appendingPathComponent("Scripts/ensure-app-group-capability.sh"),
            encoding: .utf8
        )

        XCTAssertTrue(patchScript.contains("com.apple.ApplicationGroups"))
        XCTAssertTrue(patchScript.contains("LimitLens"))
        XCTAssertTrue(patchScript.contains("LimitLensWidgetExtension"))
    }

    func testWidgetExtensionBuildSettingsEnableSandbox() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let projectSpec = try String(
            contentsOf: root.appendingPathComponent("project.yml"),
            encoding: .utf8
        )

        let widgetTarget = try XCTUnwrap(
            projectSpec.range(of: "  LimitLensWidgetExtension:").map {
                String(projectSpec[$0.lowerBound...])
            }
        )

        XCTAssertTrue(widgetTarget.contains("ENABLE_APP_SANDBOX: YES"))
    }

    func testWidgetProviderDoesNotWriteDiagnosticFilesDuringTimelineRendering() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let widgetSource = try String(
            contentsOf: root.appendingPathComponent("Sources/LimitLensWidget/LimitLensWidget.swift"),
            encoding: .utf8
        )

        XCTAssertFalse(widgetSource.contains("writeDiag("))
        XCTAssertFalse(widgetSource.contains("containerURL("))
    }

    func testWidgetCanReadApplicationSupportSnapshot() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let entitlements = try String(
            contentsOf: root.appendingPathComponent("Sources/LimitLensWidget/LimitLensWidget.entitlements"),
            encoding: .utf8
        )

        XCTAssertTrue(entitlements.contains("com.apple.security.temporary-exception.files.home-relative-path.read-only"))
        XCTAssertTrue(entitlements.contains("/Library/Application Support/LimitLens/"))
    }

    func testWidgetBundleExposesProviderSpecificWidgets() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let bundle = try String(
            contentsOf: root.appendingPathComponent("Sources/LimitLensWidget/LimitLensWidgetBundle.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(bundle.contains("@WidgetBundleBuilder"))
        XCTAssertTrue(bundle.contains("LimitLensClaudeSmallWidget()"))
        XCTAssertTrue(bundle.contains("LimitLensCodexSmallWidget()"))
        XCTAssertTrue(bundle.contains("LimitLensClaudeMediumWidget()"))
        XCTAssertTrue(bundle.contains("LimitLensCodexMediumWidget()"))
        XCTAssertTrue(bundle.contains("LimitLensClaudeLargeWidget()"))
        XCTAssertTrue(bundle.contains("LimitLensCodexLargeWidget()"))
        XCTAssertTrue(bundle.contains("LimitLensOverviewLargeWidget()"))
    }

    func testMenuBarPublishesWidgetsOnlyAfterFirstRefresh() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let menuBar = try String(
            contentsOf: root.appendingPathComponent("Sources/LimitLens/MenuBarLabel.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(menuBar.contains("store.lastRefresh != nil"))
        XCTAssertFalse(menuBar.contains("initial: true"))
    }

    func testWidgetExtensionVersionFollowsProjectVersion() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let projectSpec = try String(
            contentsOf: root.appendingPathComponent("project.yml"),
            encoding: .utf8
        )

        XCTAssertTrue(projectSpec.contains("MARKETING_VERSION: \"0.2.3\""))
        XCTAssertTrue(projectSpec.contains("CURRENT_PROJECT_VERSION: \"4\""))
        XCTAssertTrue(projectSpec.contains("CFBundleShortVersionString: \"$(MARKETING_VERSION)\""))
        XCTAssertTrue(projectSpec.contains("CFBundleVersion: \"$(CURRENT_PROJECT_VERSION)\""))
    }

    func testProviderSpecificWidgetDisplayNamesAreDistinctBySize() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let widgetSource = try String(
            contentsOf: root.appendingPathComponent("Sources/LimitLensWidget/LimitLensWidget.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(widgetSource.contains(".configurationDisplayName(\"LimitLens Claude petit\")"))
        XCTAssertTrue(widgetSource.contains(".configurationDisplayName(\"LimitLens OpenAI petit\")"))
        XCTAssertTrue(widgetSource.contains(".configurationDisplayName(\"LimitLens Claude moyen\")"))
        XCTAssertTrue(widgetSource.contains(".configurationDisplayName(\"LimitLens OpenAI moyen\")"))
        XCTAssertTrue(widgetSource.contains(".configurationDisplayName(\"LimitLens Claude grand\")"))
        XCTAssertTrue(widgetSource.contains(".configurationDisplayName(\"LimitLens OpenAI grand\")"))
        XCTAssertTrue(widgetSource.contains(".configurationDisplayName(\"LimitLens Vue d'ensemble\")"))
    }

    func testInstallScriptRegistersTheInstalledWidgetExtension() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let installScript = try String(
            contentsOf: root.appendingPathComponent("Scripts/install-app.sh"),
            encoding: .utf8
        )

        XCTAssertTrue(installScript.contains("pluginkit -r"))
        XCTAssertTrue(installScript.contains("pluginkit -a"))
        XCTAssertTrue(installScript.contains("pluginkit -e use -i \"$WIDGET_ID\""))
        XCTAssertTrue(installScript.contains("pluginkit -m -A -D -vvv"))
        XCTAssertTrue(installScript.contains("Path = "))
        XCTAssertTrue(installScript.contains("LSREGISTER="))
        XCTAssertTrue(installScript.contains("APP_BUNDLE_ID=\"com.limitlens.dashboard\""))
        XCTAssertTrue(installScript.contains("\"$LSREGISTER\" -dump"))
        XCTAssertTrue(installScript.contains("identifier:"))
        XCTAssertTrue(installScript.contains("\"$SOURCE_APP\""))
        XCTAssertTrue(installScript.contains(".build/xcode/Build/Products/Release/$APP_NAME"))
        XCTAssertTrue(installScript.contains("unregister_app_path()"))
        XCTAssertTrue(installScript.contains("\"$LSREGISTER\" -u \"$app_path\""))
        XCTAssertTrue(installScript.contains("*/LimitLens.app)"))
        XCTAssertTrue(installScript.contains("cp -R \"$SOURCE_APP\" \"$app_path\""))
        XCTAssertTrue(installScript.contains("-f -R -trusted"))
        XCTAssertTrue(installScript.contains("-gc"))
        XCTAssertTrue(installScript.contains("$DEST_DIR/$APP_NAME"))

        let appRegistrationRange = try XCTUnwrap(
            installScript.range(of: "\"$LSREGISTER\" -f -R -trusted \"$INSTALLED_APP\"")
        )
        let widgetRegistrationRange = try XCTUnwrap(
            installScript.range(of: "pluginkit -a \"$WIDGET_EXTENSION\"")
        )
        XCTAssertLessThan(
            appRegistrationRange.lowerBound,
            widgetRegistrationRange.lowerBound,
            "LaunchServices must know the containing app before pluginkit registers its widget extension."
        )
    }

    func testArchiveScriptCreatesDeveloperIDZipArtifact() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let archiveScript = try String(
            contentsOf: root.appendingPathComponent("Scripts/archive-app.sh"),
            encoding: .utf8
        )

        XCTAssertTrue(archiveScript.contains("xcodegen generate"))
        XCTAssertTrue(archiveScript.contains("xcodebuild"))
        XCTAssertTrue(archiveScript.contains("archive"))
        XCTAssertTrue(archiveScript.contains("-archivePath \"$ARCHIVE_PATH\""))
        XCTAssertTrue(archiveScript.contains("-exportArchive"))
        XCTAssertTrue(archiveScript.contains("method"))
        XCTAssertTrue(archiveScript.contains("developer-id"))
        XCTAssertTrue(archiveScript.contains("ditto -c -k --keepParent"))
        XCTAssertTrue(archiveScript.contains("ZIP_PATH=\"$DIST_DIR/LimitLens.zip\""))
    }

    func testNotarizationScriptSubmitsWaitsAndStaples() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let notarizeScript = try String(
            contentsOf: root.appendingPathComponent("Scripts/notarize-app.sh"),
            encoding: .utf8
        )

        XCTAssertTrue(notarizeScript.contains("NOTARYTOOL_PROFILE"))
        XCTAssertTrue(notarizeScript.contains("xcrun notarytool submit"))
        XCTAssertTrue(notarizeScript.contains("--wait"))
        XCTAssertTrue(notarizeScript.contains("xcrun stapler staple"))
        XCTAssertTrue(notarizeScript.contains("LimitLens.app"))
        XCTAssertTrue(notarizeScript.contains("ditto -x -k"))
    }
}

private func readPlist(_ path: String) throws -> [String: Any] {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let url = root.appendingPathComponent(path)
    let data = try Data(contentsOf: url)
    let object = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
    return try XCTUnwrap(object as? [String: Any])
}
