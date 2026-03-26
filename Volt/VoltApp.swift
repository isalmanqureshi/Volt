import SwiftUI
internal import os

@main
struct VoltApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var appContainer = AppContainer.bootstrap()

    init() {
        if ProcessInfo.processInfo.arguments.contains("UITEST_RESET") {
            UserDefaults.standard.removeObject(forKey: "volt.app_preferences")
            UserDefaults.standard.removeObject(forKey: "volt.ui_restoration")
            AppLogger.app.debug("UI test reset applied")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(appContainer)
                .task {
                    await appContainer.lifecycleCoordinator.onLaunch()
                }
                .onChange(of: scenePhase) { _, newValue in
                    appContainer.lifecycleCoordinator.handleScenePhase(newValue)
                }
        }
    }
}
