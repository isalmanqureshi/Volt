import SwiftUI

@available(*, deprecated, message: "Use RootTabView")
struct ContentView: View {
    var body: some View {
        RootTabView()
            .environmentObject(AppContainer.bootstrap())
    }
}
