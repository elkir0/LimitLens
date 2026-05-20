import AppKit
import LimitLensCore

@MainActor
struct FolderPermissionPicker {
    let bookmarkStore: FolderBookmarkStore

    init(bookmarkStore: FolderBookmarkStore = SecurityScopedFolderBookmarkStore()) {
        self.bookmarkStore = bookmarkStore
    }

    func pickFolder(prompt: String, defaultURL: URL? = nil) async throws -> Data? {
        try await withCheckedThrowingContinuation { continuation in
            let previousPolicy = NSApp.activationPolicy()
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)

            let panel = makePanel(prompt: prompt, defaultURL: defaultURL)
            panel.begin { response in
                NSApp.setActivationPolicy(previousPolicy)
                guard response == .OK, let url = panel.url else {
                    continuation.resume(returning: nil)
                    return
                }
                do {
                    continuation.resume(returning: try bookmarkStore.bookmarkData(for: url))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func makePanel(prompt: String, defaultURL: URL?) -> NSOpenPanel {
        let panel = NSOpenPanel()
        panel.title = prompt
        panel.prompt = String(localized: "setup.chooseFolder.confirm")
        panel.message = prompt
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.showsHiddenFiles = true
        panel.level = .floating
        if let defaultURL, FileManager.default.fileExists(atPath: defaultURL.path) {
            panel.directoryURL = defaultURL
        }
        return panel
    }
}
