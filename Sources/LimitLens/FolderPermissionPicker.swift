import AppKit
import LimitLensCore

struct FolderPermissionPicker {
    let bookmarkStore: FolderBookmarkStore

    init(bookmarkStore: FolderBookmarkStore = SecurityScopedFolderBookmarkStore()) {
        self.bookmarkStore = bookmarkStore
    }

    func pickFolder(prompt: String, defaultURL: URL? = nil) throws -> Data? {
        let panel = NSOpenPanel()
        panel.title = prompt
        panel.prompt = String(localized: "setup.chooseFolder.confirm")
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        if let defaultURL, FileManager.default.fileExists(atPath: defaultURL.path) {
            panel.directoryURL = defaultURL
        }
        guard panel.runModal() == .OK, let url = panel.url else {
            return nil
        }
        return try bookmarkStore.bookmarkData(for: url)
    }
}
