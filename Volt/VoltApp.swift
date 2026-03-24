import SwiftUI

@main
struct VoltApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var appContainer = AppContainer.bootstrap()

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
