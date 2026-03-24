import SwiftUI

struct RootTabView: View {
    @EnvironmentObject private var container: AppContainer
    @State private var selectedTab: AppLifecycleCoordinator.Tab = .watchlist

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                WatchlistView(viewModel: container.makeWatchlistViewModel())
                    .navigationDestination(for: AppRoute.self) { route in
                        switch route {
                        case .assetDetail(let asset):
                            AssetDetailView(viewModel: container.makeAssetDetailViewModel(asset: asset))
                        }
                    }
            }
            .tag(AppLifecycleCoordinator.Tab.watchlist)
            .tabItem {
                Label("Watchlist", systemImage: "chart.line.uptrend.xyaxis")
            }

            NavigationStack {
                PortfolioView(viewModel: container.makePortfolioViewModel())
            }
            .tag(AppLifecycleCoordinator.Tab.portfolio)
            .tabItem {
                Label("Portfolio", systemImage: "briefcase.fill")
            }

            NavigationStack {
                OrdersView(viewModel: container.makeOrdersViewModel())
            }
            .tag(AppLifecycleCoordinator.Tab.history)
            .tabItem {
                Label("History", systemImage: "clock.arrow.circlepath")
            }

            NavigationStack {
                AnalyticsView(viewModel: container.makeAnalyticsViewModel())
            }
            .tag(AppLifecycleCoordinator.Tab.analytics)
            .tabItem {
                Label("Analytics", systemImage: "chart.bar.xaxis")
            }

            NavigationStack {
                SettingsView(environmentName: container.environmentProvider.currentEnvironment.displayName)
            }
            .tag(AppLifecycleCoordinator.Tab.settings)
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
        }
        .onAppear {
            selectedTab = container.lifecycleCoordinator.restoreTab()
        }
        .onChange(of: selectedTab) { _, newValue in
            container.lifecycleCoordinator.persistTab(newValue)
        }
    }
}

#Preview {
    RootTabView()
        .environmentObject(AppContainer.bootstrap())
}
