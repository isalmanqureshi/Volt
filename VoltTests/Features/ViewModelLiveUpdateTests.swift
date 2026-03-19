import Combine
import XCTest
@testable import Volt

@MainActor
final class ViewModelLiveUpdateTests: XCTestCase {
    func testWatchlistViewModelReceivesUpdates() {
        let repository = TestMarketDataRepository()
        let viewModel = WatchlistViewModel(marketDataRepository: repository, assets: SupportedAssets.demoAssets)

        repository.emit(quotes: [Quote(symbol: "BTC/USD", lastPrice: 70_000, changePercent: 1.2, timestamp: .now, source: "seed", isSimulated: false)])

        XCTAssertEqual(viewModel.rows.first?.symbol, "BTC/USD")
        repository.emit(quotes: [Quote(symbol: "BTC/USD", lastPrice: 70_100, changePercent: 1.2, timestamp: .now, source: "sim", isSimulated: true)])
        XCTAssertEqual(viewModel.rows.first?.isSimulated, true)
    }

    func testPortfolioViewModelReceivesPositionUpdates() {
        let marketRepository = TestMarketDataRepository()
        let portfolioRepository = InMemoryPortfolioRepository(marketDataRepository: marketRepository)
        let viewModel = PortfolioViewModel(portfolioRepository: portfolioRepository)

        marketRepository.emit(quotes: [
            Quote(symbol: "BTC/USD", lastPrice: 69_500, changePercent: 0, timestamp: .now, source: "sim", isSimulated: true),
            Quote(symbol: "ETH/USD", lastPrice: 3_600, changePercent: 0, timestamp: .now, source: "sim", isSimulated: true),
            Quote(symbol: "SOL/USD", lastPrice: 180, changePercent: 0, timestamp: .now, source: "sim", isSimulated: true)
        ])

        XCTAssertFalse(viewModel.positions.isEmpty)
        XCTAssertNotEqual(viewModel.summary.totalEquity, viewModel.summary.cashBalance)
    }
}

private final class TestMarketDataRepository: MarketDataRepository {
    private let quotesSubject = CurrentValueSubject<[Quote], Never>([])

    var quotesPublisher: AnyPublisher<[Quote], Never> { quotesSubject.eraseToAnyPublisher() }
    var tickPublisher: AnyPublisher<MarketTick, Never> { Empty().eraseToAnyPublisher() }
    var connectionStatePublisher: AnyPublisher<StreamConnectionState, Never> { Just(.liveSimulated).eraseToAnyPublisher() }
    var seedingStatePublisher: AnyPublisher<MarketSeedingState, Never> { Just(.ready).eraseToAnyPublisher() }

    func start() async {}
    func quote(for symbol: String) -> Quote? { quotesSubject.value.first(where: { $0.symbol == symbol }) }
    func quotePublisher(for symbol: String) -> AnyPublisher<Quote?, Never> {
        quotesPublisher.map { $0.first(where: { $0.symbol == symbol }) }.eraseToAnyPublisher()
    }

    func watchlistQuotes(for symbols: [String]) -> AnyPublisher<[Quote], Never> {
        quotesPublisher.map { quotes in quotes.filter { symbols.contains($0.symbol) } }.eraseToAnyPublisher()
    }

    func fetchRecentCandles(symbol: String, outputSize: Int) async throws -> [Candle] { [] }

    func emit(quotes: [Quote]) {
        quotesSubject.send(quotes)
    }
}
