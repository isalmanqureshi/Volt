import Combine
import Foundation
internal import os

/// Coordinates seeded historical candles and shared live quote updates for one asset detail screen.
@MainActor
final class AssetDetailViewModel: ObservableObject {
    enum ChartState: Equatable {
        case idle
        case loading
        case loaded
        case empty
        case failed(String)
    }

    @Published var latestQuote: Quote?
    @Published var candles: [Candle] = []
    @Published var chartState: ChartState = .idle
    @Published private(set) var openPosition: Position?

    let asset: Asset

    var currentPriceText: String {
        guard let quote = latestQuote else { return "--" }
        return quote.lastPrice.formatted(.number.precision(.fractionLength(0...asset.pricePrecision)))
    }

    var changeText: String {
        guard let quote = latestQuote else { return "--" }
        return "\(quote.changePercent.formatted(.number.precision(.fractionLength(2))))%"
    }

    var isPriceUp: Bool {
        guard let quote = latestQuote else { return true }
        return quote.changePercent >= 0
    }

    var liveStatusText: String {
        latestQuote?.isSimulated == true ? "Simulated Live" : "Seeded"
    }

    var lastUpdatedText: String {
        guard let timestamp = latestQuote?.timestamp else { return "--" }
        return timestamp.formatted(date: .omitted, time: .standard)
    }

    var canRenderChart: Bool {
        !candles.isEmpty
    }

    private let marketDataRepository: MarketDataRepository
    private let portfolioRepository: PortfolioRepository
    private let defaultCandleOutputSize: Int
    private var quoteCancellable: AnyCancellable?
    private var positionCancellable: AnyCancellable?
    private var candleTask: Task<Void, Never>?
    private var hasStarted = false

    init(asset: Asset, marketDataRepository: MarketDataRepository, portfolioRepository: PortfolioRepository, defaultCandleOutputSize: Int) {
        self.asset = asset
        self.marketDataRepository = marketDataRepository
        self.portfolioRepository = portfolioRepository
        self.defaultCandleOutputSize = defaultCandleOutputSize
    }


    func onAppear() {
        guard hasStarted == false else { return }
        hasStarted = true

        AppLogger.market.info("Asset detail opened for \(self.asset.symbol, privacy: .public)")
        AppLogger.market.debug("Asset detail quote subscription started for \(self.asset.symbol, privacy: .public)")

        quoteCancellable = marketDataRepository.quotePublisher(for: asset.symbol)
            .receive(on: RunLoop.main)
            .sink { [weak self] quote in
                self?.latestQuote = quote
            }

        candleTask = Task { [weak self] in
            await self?.loadCandlesIfNeeded()
        }

        positionCancellable = portfolioRepository.positionsPublisher
            .map { [asset] positions in positions.first(where: { $0.symbol == asset.symbol }) }
            .receive(on: RunLoop.main)
            .sink { [weak self] position in
                self?.openPosition = position
            }
    }


    func onDisappear() {
        AppLogger.market.debug("Asset detail quote subscription stopped for \(self.asset.symbol, privacy: .public)")
        quoteCancellable?.cancel()
        positionCancellable?.cancel()
        candleTask?.cancel()
        hasStarted = false
    }

    func loadCandlesIfNeeded() async {
        guard candles.isEmpty else { return }
        chartState = .loading
        AppLogger.market.info("Asset detail candle fetch started for \(self.asset.symbol, privacy: .public)")

        do {
            let fetched = try await marketDataRepository.fetchRecentCandles(
                symbol: asset.symbol,
                outputSize: defaultCandleOutputSize
            )
            let sorted = fetched.sorted(by: { $0.timestamp < $1.timestamp })
            candles = sorted
            chartState = sorted.isEmpty ? .empty : .loaded
            AppLogger.market.info("Asset detail candle fetch succeeded for \(self.asset.symbol, privacy: .public): \(sorted.count, privacy: .public) bars")
        } catch {
            chartState = .failed(error.localizedDescription)
            AppLogger.market.error("Asset detail candle fetch failed for \(self.asset.symbol, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }
}
