import SwiftUI

struct RootTabView: View {
    @EnvironmentObject private var container: AppContainer
    @State private var selectedTab: AppLifecycleCoordinator.Tab = .watchlist
    @State private var showOnboarding = false
    @State private var tabDependencies: TabDependencies?

    var body: some View {
        Group {
            if let tabDependencies {
                TabView(selection: $selectedTab) {
                    NavigationStack {
                        WatchlistView(viewModel: tabDependencies.watchlist)
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
                        PortfolioView(viewModel: tabDependencies.portfolio)
                    }
                    .tag(AppLifecycleCoordinator.Tab.portfolio)
                    .tabItem {
                        Label("Portfolio", systemImage: "briefcase.fill")
                    }

                    NavigationStack {
                        OrdersView(viewModel: tabDependencies.orders)
                    }
                    .tag(AppLifecycleCoordinator.Tab.history)
                    .tabItem {
                        Label("History", systemImage: "clock.arrow.circlepath")
                    }

                    NavigationStack {
                        AnalyticsView(viewModel: tabDependencies.analytics)
                    }
                    .tag(AppLifecycleCoordinator.Tab.analytics)
                    .tabItem {
                        Label("Analytics", systemImage: "chart.bar.xaxis")
                    }

                    NavigationStack {
                        SettingsView(viewModel: tabDependencies.settings)
                    }
                    .tag(AppLifecycleCoordinator.Tab.settings)
                    .tabItem {
                        Label("Settings", systemImage: "gearshape")
                    }
                }
            } else {
                ProgressView()
            }
        }
        .onAppear {
            if tabDependencies == nil {
                tabDependencies = TabDependencies(container: container)
            }
            selectedTab = container.lifecycleCoordinator.restoreTab()
            showOnboarding = container.preferencesStore.currentPreferences.onboardingCompleted == false
        }
        .onReceive(container.preferencesStore.preferencesPublisher) { preferences in
            showOnboarding = preferences.onboardingCompleted == false
        }
        .onChange(of: selectedTab) { _, newValue in
            container.lifecycleCoordinator.persistTab(newValue)
        }
        .overlay(alignment: .topTrailing) {
            Text("Volt RC • \(container.preferencesStore.currentPreferences.activeRuntimeProfile.name)")
                .font(.caption2.weight(.semibold))
                .padding(6)
                .background(.thinMaterial, in: Capsule())
                .padding(.trailing, 10)
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView(viewModel: OnboardingViewModel(preferences: container.preferencesStore))
        }
    }
}

private struct TabDependencies {
    let watchlist: WatchlistViewModel
    let portfolio: PortfolioViewModel
    let orders: OrdersViewModel
    let analytics: AnalyticsViewModel
    let settings: SettingsViewModel

    init(container: AppContainer) {
        watchlist = container.makeWatchlistViewModel()
        portfolio = container.makePortfolioViewModel()
        orders = container.makeOrdersViewModel()
        analytics = container.makeAnalyticsViewModel()
        settings = container.makeSettingsViewModel()
    }
}

#Preview {
    RootTabView()
        .environmentObject(AppContainer.bootstrap())
}
