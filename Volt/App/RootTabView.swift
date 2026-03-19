import SwiftUI

struct RootTabView: View {
    @EnvironmentObject private var container: AppContainer

    var body: some View {
        TabView {
            NavigationStack {
                WatchlistView(
                    viewModel: container.makeWatchlistViewModel(),
                    detailViewFactory: { symbol in
                        AssetDetailView(viewModel: container.makeAssetDetailViewModel(symbol: symbol))
                    }
                )
            }
            .tabItem {
                Label("Watchlist", systemImage: "chart.line.uptrend.xyaxis")
            }

            NavigationStack {
                PortfolioView(viewModel: container.makePortfolioViewModel())
            }
            .tabItem {
                Label("Portfolio", systemImage: "briefcase.fill")
            }

            NavigationStack {
                SettingsView(environmentName: container.environmentProvider.currentEnvironment.displayName)
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
        }
    }
}

#Preview {
    RootTabView()
        .environmentObject(AppContainer.bootstrap())
}
