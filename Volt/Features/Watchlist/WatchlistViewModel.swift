import Combine
import Foundation

@MainActor
final class WatchlistViewModel: ObservableObject {
    struct RowState: Identifiable, Equatable {
        let id: String
        let symbol: String
        let name: String
        let priceText: String
        let sourceText: String
        let isSimulated: Bool
    }

    @Published private(set) var rows: [RowState] = []
    @Published private(set) var connectionState: StreamConnectionState = .idle

    private let marketDataRepository: MarketDataRepository
    private let assetsBySymbol: [String: Asset]
    private var cancellables = Set<AnyCancellable>()

    init(marketDataRepository: MarketDataRepository, assets: [Asset]) {
        self.marketDataRepository = marketDataRepository
        self.assetsBySymbol = Dictionary(uniqueKeysWithValues: assets.map { ($0.symbol, $0) })
        bind()
    }

    private func bind() {
        marketDataRepository.quotesPublisher
            .map { [weak self] quotes in
                quotes.compactMap { quote -> RowState? in
                    guard let asset = self?.assetsBySymbol[quote.symbol] else { return nil }
                    return RowState(
                        id: asset.id,
                        symbol: quote.symbol,
                        name: asset.displayName,
                        priceText: quote.lastPrice.formatted(.number.precision(.fractionLength(0...asset.pricePrecision))),
                        sourceText: quote.source,
                        isSimulated: quote.isSimulated
                    )
                }
                .sorted(by: { $0.symbol < $1.symbol })
            }
            .receive(on: RunLoop.main)
            .assign(to: &$rows)

        marketDataRepository.connectionStatePublisher
            .receive(on: RunLoop.main)
            .assign(to: &$connectionState)
    }
}
