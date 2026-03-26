import Combine
import XCTest
@testable import Volt

@MainActor
final class AssetDetailViewModelTests: XCTestCase {
    func testLoadsCandlesSortedChronologically() async {
        let repository = AssetDetailTestRepository()
        let asset = SupportedAssets.demoAssets[0]
        let viewModel = AssetDetailViewModel(asset: asset, marketDataRepository: repository, portfolioRepository: AssetDetailPortfolioStub(), defaultCandleOutputSize: 3)

        viewModel.onAppear()
        await Task.yield()

        XCTAssertEqual(viewModel.chartState, .loaded)
        XCTAssertEqual(viewModel.candles.map(\.timestamp), viewModel.candles.map(\.timestamp).sorted())
    }

    func testLatestQuoteUpdatesPropagateToDetailState() {
        let repository = AssetDetailTestRepository()
        let asset = SupportedAssets.demoAssets[0]
        let viewModel = AssetDetailViewModel(asset: asset, marketDataRepository: repository, portfolioRepository: AssetDetailPortfolioStub(), defaultCandleOutputSize: 3)

        viewModel.onAppear()

        let quote = Quote(symbol: asset.symbol, lastPrice: 70_123.45, changePercent: 0.82, timestamp: .now, source: "test", isSimulated: true)
        repository.push(quote: quote)

        XCTAssertEqual(viewModel.latestQuote, quote)
        XCTAssertEqual(viewModel.currentPriceText, quote.lastPrice.formatted(.number.precision(.fractionLength(0...asset.pricePrecision))))
        XCTAssertEqual(viewModel.liveStatusText, "Simulated Live")
    }

    func testCandleFetchFailureStillShowsQuoteState() async {
        let repository = AssetDetailTestRepository(candleError: URLError(.cannotLoadFromNetwork))
        let asset = SupportedAssets.demoAssets[1]
        let viewModel = AssetDetailViewModel(asset: asset, marketDataRepository: repository, portfolioRepository: AssetDetailPortfolioStub(), defaultCandleOutputSize: 3)

        viewModel.onAppear()
        repository.push(
            quote: Quote(symbol: asset.symbol, lastPrice: 3_500, changePercent: -1.8, timestamp: .now, source: "test", isSimulated: true)
        )
        await Task.yield()

        if case .failed = viewModel.chartState {
            XCTAssertEqual(viewModel.latestQuote?.symbol, asset.symbol)
            XCTAssertNotEqual(viewModel.currentPriceText, "--")
            XCTAssertEqual(viewModel.liveStatusText, "Simulated Live")
        } else {
            XCTFail("Expected chart failure state")
        }
    }
}

private final class AssetDetailTestRepository: MarketDataRepository {
    private let quoteSubject = CurrentValueSubject<[Quote], Never>([])
    private let candleError: Error?

    init(candleError: Error? = nil) {
        self.candleError = candleError
    }

    var quotesPublisher: AnyPublisher<[Quote], Never> { quoteSubject.eraseToAnyPublisher() }
    var tickPublisher: AnyPublisher<MarketTick, Never> { Empty().eraseToAnyPublisher() }
    var connectionStatePublisher: AnyPublisher<StreamConnectionState, Never> { Just(.liveSimulated).eraseToAnyPublisher() }
    var seedingStatePublisher: AnyPublisher<MarketSeedingState, Never> { Just(.ready).eraseToAnyPublisher() }

    func start() async {}

    func quote(for symbol: String) -> Quote? {
        quoteSubject.value.first { $0.symbol == symbol }
    }

    func quotePublisher(for symbol: String) -> AnyPublisher<Quote?, Never> {
        quotesPublisher
            .map { quotes in quotes.first(where: { $0.symbol == symbol }) }
            .eraseToAnyPublisher()
    }

    func watchlistQuotes(for symbols: [String]) -> AnyPublisher<[Quote], Never> {
        quotesPublisher
            .map { quotes in quotes.filter { symbols.contains($0.symbol) } }
            .eraseToAnyPublisher()
    }

    func fetchRecentCandles(symbol: String, outputSize: Int) async throws -> [Candle] {
        if let candleError {
            throw candleError
        }

        let now = Date()
        return [
            Candle(symbol: symbol, interval: "1min", open: 100, high: 103, low: 99, close: 102, volume: 1_000, timestamp: now, isComplete: true),
            Candle(symbol: symbol, interval: "1min", open: 98, high: 101, low: 97, close: 100, volume: 1_100, timestamp: now.addingTimeInterval(-60), isComplete: true),
            Candle(symbol: symbol, interval: "1min", open: 96, high: 99, low: 95, close: 98, volume: 1_150, timestamp: now.addingTimeInterval(-120), isComplete: true)
        ]
    }

    func push(quote: Quote) {
        var quotes = quoteSubject.value.filter { $0.symbol != quote.symbol }
        quotes.append(quote)
        quoteSubject.send(quotes)
    }
}


private struct AssetDetailPortfolioStub: PortfolioRepository {
    var positionsPublisher: AnyPublisher<[Position], Never> { Just([]).eraseToAnyPublisher() }
    var summaryPublisher: AnyPublisher<PortfolioSummary, Never> { Just(.init(cashBalance: 0, positionsMarketValue: 0, unrealizedPnL: 0, realizedPnL: 0, totalEquity: 0, dayChange: 0)).eraseToAnyPublisher() }
    var orderHistoryPublisher: AnyPublisher<[OrderRecord], Never> { Just([]).eraseToAnyPublisher() }
    var activityTimelinePublisher: AnyPublisher<[ActivityEvent], Never> { Just([]).eraseToAnyPublisher() }
    var realizedPnLPublisher: AnyPublisher<[RealizedPnLEntry], Never> { Just([]).eraseToAnyPublisher() }
    var currentPositions: [Position] { [] }
    var currentSummary: PortfolioSummary { .init(cashBalance: 0, positionsMarketValue: 0, unrealizedPnL: 0, realizedPnL: 0, totalEquity: 0, dayChange: 0) }
    var currentOrderHistory: [OrderRecord] { [] }
    var currentActivityTimeline: [ActivityEvent] { [] }
    var currentRealizedPnLHistory: [RealizedPnLEntry] { [] }
    func position(for symbol: String) -> Position? { nil }
    func applyFilledOrder(_ draft: OrderDraft, executionPrice: Decimal, filledAt: Date) throws -> TradeExecutionResult { throw TradingSimulationError.repositoryUnavailable }
}
