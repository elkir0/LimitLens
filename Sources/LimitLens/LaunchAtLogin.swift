import ServiceManagement

/// Thin wrapper around `SMAppService.mainApp` for the "launch at login" toggle.
/// The reported state is always read back from the system, never cached.
enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
