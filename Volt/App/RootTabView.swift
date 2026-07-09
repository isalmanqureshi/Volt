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
                            .toolbar(.hidden, for: .tabBar)
                            .navigationDestination(for: AppRoute.self) { route in
                                switch route {
                                case .assetDetail(let asset):
                                    AssetDetailView(viewModel: container.makeAssetDetailViewModel(asset: asset))
                                }
                            }
                    }
                    .tag(AppLifecycleCoordinator.Tab.watchlist)

                    NavigationStack {
                        ChartTabView()
                            .toolbar(.hidden, for: .tabBar)
                    }
                    .tag(AppLifecycleCoordinator.Tab.chart)

                    NavigationStack {
                        PortfolioView(viewModel: tabDependencies.portfolio)
                            .toolbar(.hidden, for: .tabBar)
                    }
                    .tag(AppLifecycleCoordinator.Tab.portfolio)

                    NavigationStack {
                        TradeTabView()
                            .toolbar(.hidden, for: .tabBar)
                    }
                    .tag(AppLifecycleCoordinator.Tab.trade)

                    NavigationStack {
                        AnalyticsView(viewModel: tabDependencies.analytics)
                            .toolbar(.hidden, for: .tabBar)
                    }
                    .tag(AppLifecycleCoordinator.Tab.analytics)
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    VoltTabBar(selection: $selectedTab)
                }
            } else {
                Color.voltBackground.ignoresSafeArea()
            }
        }
        .voltScreen()
        .onAppear {
            if tabDependencies == nil {
                tabDependencies = TabDependencies(container: container)
            }
            selectedTab = Self.visibleTab(for: container.lifecycleCoordinator.restoreTab())
            showOnboarding = container.preferencesStore.currentPreferences.onboardingCompleted == false
        }
        .onReceive(container.preferencesStore.preferencesPublisher) { preferences in
            showOnboarding = preferences.onboardingCompleted == false
        }
        .onChange(of: selectedTab) { _, newValue in
            container.lifecycleCoordinator.persistTab(newValue)
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView(viewModel: OnboardingViewModel(preferences: container.preferencesStore))
        }
    }

    /// History and Settings are no longer tabs; remap stale persisted selections.
    private static func visibleTab(for tab: AppLifecycleCoordinator.Tab) -> AppLifecycleCoordinator.Tab {
        switch tab {
        case .history: return .portfolio
        case .settings: return .watchlist
        default: return tab
        }
    }
}

// MARK: - Tab hosts for asset-scoped screens

/// Chart tab: full asset detail for a switchable coin (defaults to the first enabled asset).
private struct ChartTabView: View {
    @EnvironmentObject private var container: AppContainer
    @State private var selectedAsset: Asset?

    var body: some View {
        let assets = container.configuration.enabledAssets
        let asset = selectedAsset ?? assets.first ?? SupportedAssets.demoAssets[0]
        AssetDetailView(
            viewModel: container.makeAssetDetailViewModel(asset: asset),
            availableAssets: assets,
            onSelectAsset: { selectedAsset = $0 }
        )
        .id(asset.id)
    }
}

/// Trade tab: ticket for a switchable coin, kept on screen after fills so the recap shows.
private struct TradeTabView: View {
    @EnvironmentObject private var container: AppContainer
    @State private var selectedAsset: Asset?

    var body: some View {
        let assets = container.configuration.enabledAssets
        let asset = selectedAsset ?? assets.first ?? SupportedAssets.demoAssets[0]
        TradeTicketView(
            viewModel: container.makeTradeTicketViewModel(asset: asset, side: .buy),
            availableAssets: assets,
            onSelectAsset: { selectedAsset = $0 }
        )
        .id(asset.id)
    }
}

// MARK: - Custom tab bar

/// Design tab bar: teal icon + label when active, gray icon with no label otherwise.
private struct VoltTabBar: View {
    @Binding var selection: AppLifecycleCoordinator.Tab

    private static let items: [(tab: AppLifecycleCoordinator.Tab, icon: String, title: String)] = [
        (.watchlist, "list.bullet", "Watchlist"),
        (.chart, "chart.xyaxis.line", "Chart"),
        (.portfolio, "chart.pie", "Portfolio"),
        (.trade, "arrow.up.arrow.down", "Trade"),
        (.analytics, "chart.bar", "Analytics")
    ]

    var body: some View {
        VStack(spacing: 0) {
            RowDivider()
            HStack(spacing: 0) {
                ForEach(Self.items, id: \.tab) { item in
                    let isActive = selection == item.tab
                    Button {
                        selection = item.tab
                    } label: {
                        VStack(spacing: Spacing.xs) {
                            Image(systemName: item.icon)
                                .font(.system(size: 20, weight: .regular))
                                .foregroundStyle(isActive ? Color.voltAccent : Color.white.opacity(0.35))
                            if isActive {
                                Text(item.title)
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color.voltAccent)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 44, alignment: .top)
                        .padding(.top, Spacing.sm)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(item.title)
                    .accessibilityAddTraits(isActive ? [.isSelected] : [])
                }
            }
            .background(Color.voltBackground)
        }
        .background(Color.voltBackground)
    }
}

private struct TabDependencies {
    let watchlist: WatchlistViewModel
    let portfolio: PortfolioViewModel
    let analytics: AnalyticsViewModel

    init(container: AppContainer) {
        watchlist = container.makeWatchlistViewModel()
        portfolio = container.makePortfolioViewModel()
        analytics = container.makeAnalyticsViewModel()
    }
}

#Preview {
    RootTabView()
        .environmentObject(AppContainer.bootstrap())
}
