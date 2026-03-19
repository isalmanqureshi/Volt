import SwiftUI

@main
struct VoltApp: App {
    @StateObject private var appContainer = AppContainer.bootstrap()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(appContainer)
        }
    }
}
