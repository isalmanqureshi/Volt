import Combine
import XCTest
@testable import Volt

final class PendingOrderMatchingTests: XCTestCase {
    private func makeStack(cash: Decimal = 50_000) -> (market: TickDrivenMarketDataRepository, portfolio: InMemoryPortfolioRepository, service: DefaultPendingOrderMatchingService) {
        let market = TickDrivenMarketDataRepository()
        let portfolio = InMemoryPortfolioRepository(marketDataRepository: market, cashBalance: cash)
        let service = DefaultPendingOrderMatchingService(
            portfolioRepository: portfolio,
            marketDataRepository: market,
            supportedSymbols: ["BTC/USD", "ETH/USD"]
        )
        return (market, portfolio, service)
    }

    private func buy(_ portfolio: InMemoryPortfolioRepository, symbol: String, quantity: Decimal, price: Decimal) throws {
        let draft = OrderDraft(assetSymbol: symbol, side: .buy, type: .market, quantity: quantity, estimatedPrice: price, submittedAt: .now, limitPrice: nil, stopPrice: nil)
        _ = try portfolio.applyFilledOrder(draft, executionPrice: price, filledAt: .now)
    }

    func testLimitBuyRestsUntilPriceCrossesBelowTrigger() throws {
        let (market, portfolio, service) = makeStack()
        try service.place(PendingOrderRequest(symbol: "BTC/USD", side: .buy, type: .limit, quantity: 0.5, triggerPrice: 67_000, submittedAt: .now))

        market.emitTick(symbol: "BTC/USD", price: 68_000)
        XCTAssertNil(portfolio.position(for: "BTC/USD"), "Order must rest while price is above the buy trigger")
        XCTAssertEqual(service.currentPendingOrders.count, 1)

        market.emitTick(symbol: "BTC/USD", price: 66_900)
        let position = portfolio.position(for: "BTC/USD")
        XCTAssertEqual(position?.quantity, 0.5)
        XCTAssertEqual(position?.averageEntryPrice, 66_900, "Fill executes at the crossing tick price, not the trigger")
        XCTAssertTrue(service.currentPendingOrders.isEmpty)
    }

    func testStopSellFillsWhenPriceFallsToTrigger() throws {
        let (market, portfolio, service) = makeStack()
        try buy(portfolio, symbol: "BTC/USD", quantity: 0.25, price: 65_000)
        try service.place(PendingOrderRequest(symbol: "BTC/USD", side: .sell, type: .stop, quantity: 0.25, triggerPrice: 60_000, submittedAt: .now))

        market.emitTick(symbol: "BTC/USD", price: 61_000)
        XCTAssertNotNil(portfolio.position(for: "BTC/USD"), "Stop-loss must not fire above its trigger")

        market.emitTick(symbol: "BTC/USD", price: 59_500)
        XCTAssertNil(portfolio.position(for: "BTC/USD"), "Stop-loss should close the position when the price falls through the trigger")
        XCTAssertEqual(portfolio.currentRealizedPnLHistory.count, 1)
        XCTAssertEqual(portfolio.currentRealizedPnLHistory.first?.exitPrice, 59_500)
        XCTAssertTrue(service.currentPendingOrders.isEmpty)
    }

    func testOrderFillsExactlyOnce() throws {
        let (market, portfolio, service) = makeStack()
        try service.place(PendingOrderRequest(symbol: "BTC/USD", side: .buy, type: .limit, quantity: 0.25, triggerPrice: 67_000, submittedAt: .now))

        market.emitTick(symbol: "BTC/USD", price: 66_500)
        market.emitTick(symbol: "BTC/USD", price: 66_000)

        XCTAssertEqual(portfolio.currentOrderHistory.count, 1, "A second crossing tick must not fill the same order again")
        XCTAssertEqual(portfolio.position(for: "BTC/USD")?.quantity, 0.25)
    }

    func testFillRejectedWhenCashInsufficientAtFillTime() throws {
        let (market, portfolio, service) = makeStack(cash: 50_000)
        try service.place(PendingOrderRequest(symbol: "BTC/USD", side: .buy, type: .limit, quantity: 1, triggerPrice: 49_000, submittedAt: .now))
        // Cash was sufficient at placement; spend most of it before the trigger crosses.
        try buy(portfolio, symbol: "ETH/USD", quantity: 10, price: 4_000)

        market.emitTick(symbol: "BTC/USD", price: 48_500)

        XCTAssertNil(portfolio.position(for: "BTC/USD"))
        XCTAssertEqual(service.currentPendingOrders.count, 1)
        guard case .rejected = service.currentPendingOrders[0].status else {
            return XCTFail("Expected the order to be kept with a rejected status")
        }
    }

    func testCancelRemovesRestingOrder() throws {
        let (market, portfolio, service) = makeStack()
        let order = try service.place(PendingOrderRequest(symbol: "BTC/USD", side: .buy, type: .limit, quantity: 0.5, triggerPrice: 67_000, submittedAt: .now))

        service.cancel(id: order.id)
        XCTAssertTrue(service.currentPendingOrders.isEmpty)

        market.emitTick(symbol: "BTC/USD", price: 66_000)
        XCTAssertNil(portfolio.position(for: "BTC/USD"), "A cancelled order must never fill")
    }

    func testSellPlacementRequiresCoveringPosition() {
        let (_, _, service) = makeStack()
        XCTAssertThrowsError(
            try service.place(PendingOrderRequest(symbol: "BTC/USD", side: .sell, type: .limit, quantity: 1, triggerPrice: 70_000, submittedAt: .now))
        ) { error in
            XCTAssertEqual(error as? PendingOrderError, .missingPosition(symbol: "BTC/USD"))
        }
    }

    func testMarketOrderTypeIsRefusedByTheBook() {
        let (_, _, service) = makeStack()
        XCTAssertThrowsError(
            try service.place(PendingOrderRequest(symbol: "BTC/USD", side: .buy, type: .market, quantity: 1, triggerPrice: 70_000, submittedAt: .now))
        ) { error in
            XCTAssertEqual(error as? PendingOrderError, .unsupportedOrderType)
        }
    }
}

/// Market data double whose tick stream is driven synchronously by the test.
private final class TickDrivenMarketDataRepository: MarketDataRepository {
    private let quotesSubject = CurrentValueSubject<[Quote], Never>([])
    private let tickSubject = PassthroughSubject<MarketTick, Never>()

    var quotesPublisher: AnyPublisher<[Quote], Never> { quotesSubject.eraseToAnyPublisher() }
    var tickPublisher: AnyPublisher<MarketTick, Never> { tickSubject.eraseToAnyPublisher() }
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

    func emitTick(symbol: String, price: Decimal) {
        tickSubject.send(MarketTick(symbol: symbol, price: price, timestamp: Date(), isSimulated: true))
    }
}
