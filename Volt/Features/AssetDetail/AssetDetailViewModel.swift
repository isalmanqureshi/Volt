import Combine
import Foundation

@MainActor
final class AssetDetailViewModel: ObservableObject {
    @Published private(set) var latestQuote: Quote?
    @Published private(set) var candles: [Candle] = []
    @Published private(set) var errorMessage: String?
    @Published private(set) var isLoadingCandles = false

    let symbol: String

    private let marketDataRepository: MarketDataRepository
    private let defaultCandleOutputSize: Int
    private var cancellables = Set<AnyCancellable>()

    init(symbol: String, marketDataRepository: MarketDataRepository, defaultCandleOutputSize: Int) {
        self.symbol = symbol
        self.marketDataRepository = marketDataRepository
        self.defaultCandleOutputSize = defaultCandleOutputSize

        marketDataRepository.quotePublisher(for: symbol)
            .receive(on: RunLoop.main)
            .assign(to: &$latestQuote)
    }

    func loadCandlesIfNeeded() async {
        guard candles.isEmpty else { return }
        isLoadingCandles = true
        defer { isLoadingCandles = false }
        do {
            candles = try await marketDataRepository.fetchRecentCandles(symbol: symbol, outputSize: defaultCandleOutputSize)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
