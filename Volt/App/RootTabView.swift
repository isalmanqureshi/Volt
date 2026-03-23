import SwiftUI

struct RootTabView: View {
    @EnvironmentObject private var container: AppContainer

    var body: some View {
        TabView {
            NavigationStack {
                WatchlistView(viewModel: container.makeWatchlistViewModel())
                    .navigationDestination(for: AppRoute.self) { route in
                        switch route {
                        case .assetDetail(let asset):
                            AssetDetailView(viewModel: container.makeAssetDetailViewModel(asset: asset))
                        }
                    }
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
                OrdersView(viewModel: container.makeOrdersViewModel())
            }
            .tabItem {
                Label("History", systemImage: "clock.arrow.circlepath")
            }

            NavigationStack {
                AnalyticsView(viewModel: container.makeAnalyticsViewModel())
            }
            .tabItem {
                Label("Analytics", systemImage: "chart.bar.xaxis")
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
