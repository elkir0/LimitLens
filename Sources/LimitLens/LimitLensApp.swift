import LimitLensCore
import SwiftUI

@main
struct LimitLensApp: App {
    @StateObject private var appModel = LimitLensAppModel()

    var body: some Scene {
        MenuBarExtra {
            PopoverRootView()
                .environmentObject(appModel)
                .environmentObject(appModel.usageStore)
        } label: {
            MenuBarLabel(store: appModel.usageStore)
        }
        .menuBarExtraStyle(.window)
    }
}
