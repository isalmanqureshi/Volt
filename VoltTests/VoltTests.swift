import XCTest
@testable import Volt

import Combine

@MainActor
final class VoltTests: XCTestCase {
    func testBuyOrderValidationSucceedsWithFunds() throws {
        let market = TradingTestMarketDataRepository(quote: .init(symbol: "BTC/USD", lastPrice: 50_000, changePercent: 0, timestamp: .now, source: "test", isSimulated: true))
        let portfolio = InMemoryPortfolioRepository(marketDataRepository: market, cashBalance: 100_000)
        let service = DefaultTradingSimulationService(
            marketDataRepository: market,
            portfolioRepository: portfolio,
            supportedSymbols: ["BTC/USD"]
        )

        let draft = OrderDraft(assetSymbol: "BTC/USD", side: .buy, type: .market, quantity: 1, estimatedPrice: 50_000, submittedAt: .now, limitPrice: nil, stopPrice: nil)
        let result = try service.placeOrder(draft)

        XCTAssertEqual(result.orderRecord.symbol, "BTC/USD")
        XCTAssertEqual(portfolio.currentPositions.count, 1)
        XCTAssertEqual(portfolio.currentOrderHistory.count, 1)
    }

    func testBuyOrderValidationFailsForInvalidQuantity() {
        let market = TradingTestMarketDataRepository(quote: .init(symbol: "BTC/USD", lastPrice: 50_000, changePercent: 0, timestamp: .now, source: "test", isSimulated: true))
        let portfolio = InMemoryPortfolioRepository(marketDataRepository: market, cashBalance: 100_000)
        let service = DefaultTradingSimulationService(marketDataRepository: market, portfolioRepository: portfolio, supportedSymbols: ["BTC/USD"])
        let draft = OrderDraft(assetSymbol: "BTC/USD", side: .buy, type: .market, quantity: 0, estimatedPrice: nil, submittedAt: .now, limitPrice: nil, stopPrice: nil)

        XCTAssertThrowsError(try service.placeOrder(draft)) { error in
            XCTAssertEqual(error as? TradingSimulationError, .invalidQuantity)
        }
    }

    func testBuyOrderValidationFailsForInsufficientFunds() {
        let market = TradingTestMarketDataRepository(quote: .init(symbol: "BTC/USD", lastPrice: 50_000, changePercent: 0, timestamp: .now, source: "test", isSimulated: true))
        let portfolio = InMemoryPortfolioRepository(marketDataRepository: market, cashBalance: 1_000)
        let service = DefaultTradingSimulationService(marketDataRepository: market, portfolioRepository: portfolio, supportedSymbols: ["BTC/USD"])
        let draft = OrderDraft(assetSymbol: "BTC/USD", side: .buy, type: .market, quantity: 1, estimatedPrice: nil, submittedAt: .now, limitPrice: nil, stopPrice: nil)

        XCTAssertThrowsError(try service.placeOrder(draft))
    }

    func testCashBalanceAndPnLUpdateWithQuoteChanges() throws {
        let market = TradingTestMarketDataRepository(quote: .init(symbol: "ETH/USD", lastPrice: 3_000, changePercent: 0, timestamp: .now, source: "test", isSimulated: true))
        let portfolio = InMemoryPortfolioRepository(marketDataRepository: market, cashBalance: 10_000)
        let service = DefaultTradingSimulationService(marketDataRepository: market, portfolioRepository: portfolio, supportedSymbols: ["ETH/USD"])
        let draft = OrderDraft(assetSymbol: "ETH/USD", side: .buy, type: .market, quantity: 2, estimatedPrice: nil, submittedAt: .now, limitPrice: nil, stopPrice: nil)
        _ = try service.placeOrder(draft)

        XCTAssertEqual(portfolio.currentSummary.cashBalance, 4_000)

        market.emit(quote: .init(symbol: "ETH/USD", lastPrice: 3_500, changePercent: 0, timestamp: .now, source: "test", isSimulated: true))
        XCTAssertEqual(portfolio.currentSummary.unrealizedPnL, 1_000)
        XCTAssertEqual(portfolio.currentSummary.totalEquity, 11_000)
    }

    func testTradeTicketViewModelValidationAndSubmitState() {
        let market = TradingTestMarketDataRepository(quote: .init(symbol: "SOL/USD", lastPrice: 200, changePercent: 0, timestamp: .now, source: "test", isSimulated: true))
        let portfolio = InMemoryPortfolioRepository(marketDataRepository: market, cashBalance: 100)
        let service = DefaultTradingSimulationService(marketDataRepository: market, portfolioRepository: portfolio, supportedSymbols: ["SOL/USD"])
        let vm = TradeTicketViewModel(
            asset: Asset(symbol: "SOL/USD", displayName: "Solana", baseCurrency: "SOL", quoteCurrency: "USD", assetClass: .crypto, pricePrecision: 2),
            marketDataRepository: market,
            portfolioRepository: portfolio,
            tradingSimulationService: service
        )

        vm.quantityText = "1"
        XCTAssertFalse(vm.canSubmit)
        vm.quantityText = "0.2"
        XCTAssertTrue(vm.canSubmit)
        vm.submitOrder()
        XCTAssertTrue(vm.didSubmitSuccessfully)
    }
}

private final class TradingTestMarketDataRepository: MarketDataRepository {
    private let quotesSubject: CurrentValueSubject<[Quote], Never>
    init(quote: Quote) {
        quotesSubject = CurrentValueSubject([quote])
    }

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
    func emit(quote: Quote) { quotesSubject.send([quote]) }
}
