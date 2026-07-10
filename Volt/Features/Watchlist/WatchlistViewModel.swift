import Combine
import Foundation

@MainActor
final class WatchlistViewModel: ObservableObject {
    struct RowState: Identifiable, Equatable {
        let id: String
        let symbol: String
        let name: String
        let priceText: String
        let changeText: String
        let sourceText: String
        let isSimulated: Bool
    }

    @Published private(set) var rows: [RowState] = []
    @Published private(set) var connectionState: StreamConnectionState = .idle
    @Published private(set) var seedingState: MarketSeedingState = .idle
    @Published private(set) var dataMode: MarketDataMode = .liveSeeded
    @Published private(set) var isRefreshing = false
    /// Rolling recent-price buffer per symbol, presentation-only (drives row sparklines).
    @Published private(set) var sparklines: [String: [Double]] = [:]

    private let marketDataRepository: MarketDataRepository
    private let assetsBySymbol: [String: Asset]
    /// Row order is fixed by symbol, so sort once here instead of on every quote emission.
    private let sortedAssets: [Asset]
    private var cancellables = Set<AnyCancellable>()
    private let sparklineCapacity = 40

    init(marketDataRepository: MarketDataRepository, assets: [Asset]) {
        self.marketDataRepository = marketDataRepository
        self.assetsBySymbol = Dictionary(uniqueKeysWithValues: assets.map { ($0.symbol, $0) })
        self.sortedAssets = assets.sorted(by: { $0.symbol < $1.symbol })
        bind()
    }


    func refresh() {
        guard isRefreshing == false else { return }
        isRefreshing = true
        Task { [weak self] in
            await self?.marketDataRepository.manualRefresh()
            await MainActor.run {
                self?.isRefreshing = false
            }
        }
    }

    func route(for row: RowState) -> AppRoute? {
        guard let asset = assetsBySymbol[row.symbol] else { return nil }
        return .assetDetail(asset: asset)
    }

    private func bind() {
        marketDataRepository.quotesPublisher
            .map { [sortedAssets] quotes in
                let quotesBySymbol = Dictionary(quotes.map { ($0.symbol, $0) }, uniquingKeysWith: { _, latest in latest })
                return sortedAssets.compactMap { asset -> RowState? in
                    guard let quote = quotesBySymbol[asset.symbol] else { return nil }
                    return RowState(
                        id: asset.id,
                        symbol: quote.symbol,
                        name: asset.displayName,
                        priceText: quote.lastPrice.formatted(.number.precision(.fractionLength(0...asset.pricePrecision))),
                        changeText: "\(quote.changePercent.formatted(.number.precision(.fractionLength(2))))%",
                        sourceText: quote.source,
                        isSimulated: quote.isSimulated
                    )
                }
            }
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .assign(to: &$rows)

        marketDataRepository.quotesPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] quotes in
                guard let self else { return }
                var lines = self.sparklines
                var didChange = false
                for quote in quotes {
                    let value = NSDecimalNumber(decimal: quote.lastPrice).doubleValue
                    var buffer = lines[quote.symbol] ?? []
                    guard buffer.last != value else { continue }
                    buffer.append(value)
                    if buffer.count > self.sparklineCapacity {
                        buffer.removeFirst(buffer.count - self.sparklineCapacity)
                    }
                    lines[quote.symbol] = buffer
                    didChange = true
                }
                // Reassigning @Published republishes to every row's sparkline view,
                // so skip it when no symbol actually moved.
                if didChange {
                    self.sparklines = lines
                }
            }
            .store(in: &cancellables)

        marketDataRepository.connectionStatePublisher
            .receive(on: RunLoop.main)
            .assign(to: &$connectionState)

        marketDataRepository.seedingStatePublisher
            .receive(on: RunLoop.main)
            .assign(to: &$seedingState)

        marketDataRepository.dataModePublisher
            .receive(on: RunLoop.main)
            .assign(to: &$dataMode)
    }
}
