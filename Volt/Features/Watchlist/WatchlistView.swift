import Combine
import SwiftUI

struct WatchlistView: View {
    @EnvironmentObject private var container: AppContainer
    @StateObject var viewModel: WatchlistViewModel
    @State private var searchText = ""
    @State private var showSettings = false

    private var isLive: Bool {
        viewModel.connectionState == .liveSimulated
    }

    private var filteredRows: [WatchlistViewModel.RowState] {
        guard searchText.isEmpty == false else { return viewModel.rows }
        return viewModel.rows.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
                || $0.symbol.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeader("Watchlist") {
                HStack(spacing: Spacing.md) {
                    LiveDot(isLive: isLive)
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(Typography.emphasis)
                            .foregroundStyle(Color.voltTextSecondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Settings")
                }
            }

            searchBar
                .padding(.horizontal, Spacing.gutter)
                .padding(.bottom, Spacing.md)

            if case .fallbackMocked = viewModel.seedingState {
                Text("Using fallback pricing — pull to retry.")
                    .font(Typography.secondary)
                    .foregroundStyle(Color.voltTextTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Spacing.gutter)
                    .padding(.bottom, Spacing.sm)
            }

            content
        }
        .voltScreen()
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                SettingsView(viewModel: container.makeSettingsViewModel())
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(Typography.body)
                .foregroundStyle(Color.voltTextTertiary)
            TextField(
                "",
                text: $searchText,
                prompt: Text("Search coins").foregroundStyle(Color.voltTextTertiary)
            )
            .font(Typography.body)
            .foregroundStyle(Color.voltTextPrimary)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
        }
        .padding(.horizontal, Spacing.md)
        .frame(height: 40)
        .voltSurfaceStyle()
    }

    @ViewBuilder
    private var content: some View {
        if case .seeding = viewModel.seedingState, viewModel.rows.isEmpty {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(0..<6, id: \.self) { _ in
                        CoinRowSkeleton()
                        RowDivider()
                    }
                }
            }
        } else if viewModel.rows.isEmpty {
            emptyState(
                title: "No watchlist quotes",
                message: "Pull to refresh seeded prices."
            )
        } else if filteredRows.isEmpty {
            emptyState(
                title: "No matches",
                message: "No coins match “\(searchText)”."
            )
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredRows) { row in
                        if let route = viewModel.route(for: row) {
                            NavigationLink(value: route) {
                                coinRow(row)
                            }
                            .buttonStyle(.plain)
                        } else {
                            coinRow(row)
                        }
                        RowDivider()
                    }
                }
            }
            .refreshable {
                viewModel.refresh()
            }
        }
    }

    private func coinRow(_ row: WatchlistViewModel.RowState) -> some View {
        let isPositive = row.changeText.hasPrefix("-") == false
        return CoinRow(
            name: row.name,
            symbol: row.symbol,
            priceText: "$" + row.priceText,
            changeText: isPositive ? "+" + row.changeText : row.changeText,
            isPositive: isPositive,
            sparkline: viewModel.sparklines[row.symbol] ?? []
        )
    }

    private func emptyState(title: String, message: String) -> some View {
        VStack(spacing: Spacing.sm) {
            Spacer()
            Image(systemName: "chart.line.downtrend.xyaxis")
                .font(Typography.screenTitle)
                .foregroundStyle(Color.voltTextTertiary)
            Text(title)
                .font(Typography.emphasis.weight(.semibold))
                .foregroundStyle(Color.voltTextPrimary)
            Text(message)
                .font(Typography.bodySecondary)
                .foregroundStyle(Color.voltTextSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview("Populated") {
    NavigationStack {
        WatchlistView(
            viewModel: WatchlistViewModel(
                marketDataRepository: WatchlistPreviewRepository.populated,
                assets: SupportedAssets.demoAssets
            )
        )
    }
    .environmentObject(AppContainer.bootstrap())
}

#Preview("Seeding") {
    NavigationStack {
        WatchlistView(
            viewModel: WatchlistViewModel(
                marketDataRepository: WatchlistPreviewRepository.seeding,
                assets: SupportedAssets.demoAssets
            )
        )
    }
    .environmentObject(AppContainer.bootstrap())
}

private final class WatchlistPreviewRepository: MarketDataRepository {
    static let populated = WatchlistPreviewRepository(
        quotes: [
            Quote(symbol: "BTC/USD", lastPrice: 63_842.10, changePercent: 2.34, timestamp: .now, source: "preview", isSimulated: true),
            Quote(symbol: "ETH/USD", lastPrice: 3_318.72, changePercent: 1.12, timestamp: .now, source: "preview", isSimulated: true),
            Quote(symbol: "SOL/USD", lastPrice: 146.29, changePercent: -3.48, timestamp: .now, source: "preview", isSimulated: true),
            Quote(symbol: "DOGE/USD", lastPrice: 0.1621, changePercent: -1.05, timestamp: .now, source: "preview", isSimulated: true)
        ],
        seedingState: .ready
    )
    static let seeding = WatchlistPreviewRepository(quotes: [], seedingState: .seeding)

    private let quotes: [Quote]
    private let seedingState: MarketSeedingState

    private init(quotes: [Quote], seedingState: MarketSeedingState) {
        self.quotes = quotes
        self.seedingState = seedingState
    }

    var quotesPublisher: AnyPublisher<[Quote], Never> { Just(quotes).eraseToAnyPublisher() }
    var tickPublisher: AnyPublisher<MarketTick, Never> { Empty().eraseToAnyPublisher() }
    var connectionStatePublisher: AnyPublisher<StreamConnectionState, Never> { Just(.liveSimulated).eraseToAnyPublisher() }
    var seedingStatePublisher: AnyPublisher<MarketSeedingState, Never> { Just(seedingState).eraseToAnyPublisher() }
    func start() async {}
    func quote(for symbol: String) -> Quote? { quotes.first(where: { $0.symbol == symbol }) }
    func quotePublisher(for symbol: String) -> AnyPublisher<Quote?, Never> { Just(quote(for: symbol)).eraseToAnyPublisher() }
    func watchlistQuotes(for symbols: [String]) -> AnyPublisher<[Quote], Never> { Just(quotes).eraseToAnyPublisher() }
    func fetchRecentCandles(symbol: String, outputSize: Int) async throws -> [Candle] { [] }
}
