import Combine
import XCTest
@testable import Volt

@MainActor
final class Milestone6AnalyticsTests: XCTestCase {
    func testAnalyticsSummaryComputesWinRateAndAverages() throws {
        let market = AnalyticsTestMarketDataRepository(quote: .init(symbol: "BTC/USD", lastPrice: 100, changePercent: 0, timestamp: .now, source: "test", isSimulated: true))
        let repository = InMemoryPortfolioRepository(marketDataRepository: market, cashBalance: 10_000)

        _ = try repository.applyFilledOrder(.init(assetSymbol: "BTC/USD", side: .buy, type: .market, quantity: 2, estimatedPrice: nil, submittedAt: .now.addingTimeInterval(-400), limitPrice: nil, stopPrice: nil), executionPrice: 100, filledAt: .now.addingTimeInterval(-400))
        _ = try repository.applyFilledOrder(.init(assetSymbol: "BTC/USD", side: .sell, type: .market, quantity: 1, estimatedPrice: nil, submittedAt: .now.addingTimeInterval(-300), limitPrice: nil, stopPrice: nil), executionPrice: 120, filledAt: .now.addingTimeInterval(-300))
        _ = try repository.applyFilledOrder(.init(assetSymbol: "BTC/USD", side: .sell, type: .market, quantity: 1, estimatedPrice: nil, submittedAt: .now.addingTimeInterval(-200), limitPrice: nil, stopPrice: nil), executionPrice: 90, filledAt: .now.addingTimeInterval(-200))

        let service = DefaultPortfolioAnalyticsService(repository: repository)
        let summary = service.currentSummary

        XCTAssertEqual(summary.totalClosedTrades, 2)
        XCTAssertEqual(summary.totalRealizedPnL, 10)
        XCTAssertEqual(summary.averageWin, 20)
        XCTAssertEqual(summary.averageLoss, -10)
        XCTAssertEqual(summary.winRate, 0.5)
    }

    func testDateFilteringReturnsExpectedSubset() throws {
        let now = Date()
        let market = AnalyticsTestMarketDataRepository(quote: .init(symbol: "ETH/USD", lastPrice: 100, changePercent: 0, timestamp: now, source: "test", isSimulated: true))
        let repository = InMemoryPortfolioRepository(marketDataRepository: market, cashBalance: 10_000)

        _ = try repository.applyFilledOrder(.init(assetSymbol: "ETH/USD", side: .buy, type: .market, quantity: 2, estimatedPrice: nil, submittedAt: now.addingTimeInterval(-86_400 * 40), limitPrice: nil, stopPrice: nil), executionPrice: 100, filledAt: now.addingTimeInterval(-86_400 * 40))
        _ = try repository.applyFilledOrder(.init(assetSymbol: "ETH/USD", side: .sell, type: .market, quantity: 1, estimatedPrice: nil, submittedAt: now.addingTimeInterval(-86_400 * 2), limitPrice: nil, stopPrice: nil), executionPrice: 110, filledAt: now.addingTimeInterval(-86_400 * 2))

        let service = DefaultPortfolioAnalyticsService(repository: repository, nowProvider: { now })
        let expectation = XCTestExpectation(description: "filtered orders")
        let cancellable = service.filteredOrdersPublisher.sink { orders in
            XCTAssertEqual(orders.count, 1)
            expectation.fulfill()
        }
        service.updateFilter(.init(timeRange: .sevenDays, symbol: nil, eventKinds: []))
        XCTAssertEqual(service.currentFilter.timeRange, .sevenDays)
        wait(for: [expectation], timeout: 0.5)
        _ = cancellable
    }

    func testPerformancePointsAreChronologicallyOrdered() throws {
        let market = AnalyticsTestMarketDataRepository(quote: .init(symbol: "SOL/USD", lastPrice: 50, changePercent: 0, timestamp: .now, source: "test", isSimulated: true))
        let repository = InMemoryPortfolioRepository(marketDataRepository: market, cashBalance: 1_000)

        _ = try repository.applyFilledOrder(.init(assetSymbol: "SOL/USD", side: .buy, type: .market, quantity: 5, estimatedPrice: nil, submittedAt: .now.addingTimeInterval(-600), limitPrice: nil, stopPrice: nil), executionPrice: 50, filledAt: .now.addingTimeInterval(-600))
        _ = try repository.applyFilledOrder(.init(assetSymbol: "SOL/USD", side: .sell, type: .market, quantity: 2, estimatedPrice: nil, submittedAt: .now.addingTimeInterval(-300), limitPrice: nil, stopPrice: nil), executionPrice: 55, filledAt: .now.addingTimeInterval(-300))

        let service = DefaultPortfolioAnalyticsService(repository: repository)
        let timestamps = service.currentPerformance.map(\.timestamp)

        XCTAssertEqual(timestamps, timestamps.sorted())
    }

    func testPositionHistoryGroupingBySymbol() throws {
        let market = AnalyticsTestMarketDataRepository(quote: .init(symbol: "BTC/USD", lastPrice: 100, changePercent: 0, timestamp: .now, source: "test", isSimulated: true))
        let repository = InMemoryPortfolioRepository(marketDataRepository: market, cashBalance: 5_000)

        _ = try repository.applyFilledOrder(.init(assetSymbol: "BTC/USD", side: .buy, type: .market, quantity: 1, estimatedPrice: nil, submittedAt: .now.addingTimeInterval(-100), limitPrice: nil, stopPrice: nil), executionPrice: 100, filledAt: .now.addingTimeInterval(-100))
        _ = try repository.applyFilledOrder(.init(assetSymbol: "BTC/USD", side: .sell, type: .market, quantity: 0.4, estimatedPrice: nil, submittedAt: .now, limitPrice: nil, stopPrice: nil), executionPrice: 110, filledAt: .now)

        let service = DefaultPortfolioAnalyticsService(repository: repository)
        let symbolSummary = service.positionHistory(symbol: "BTC/USD")

        XCTAssertEqual(symbolSummary.totalBoughtQuantity, 1)
        XCTAssertEqual(symbolSummary.totalSoldQuantity, 0.4)
        XCTAssertEqual(symbolSummary.realizedPnL, 4)
        XCTAssertEqual(symbolSummary.orders.count, 2)
    }

    func testCSVExportContainsHeadersAndRows() throws {
        let orders = [
            OrderRecord(id: UUID(), symbol: "BTC/USD", side: .buy, type: .market, quantity: 1, executedPrice: 100, grossValue: 100, submittedAt: .now, executedAt: .now, status: .filled, source: .simulated, linkedPositionID: nil)
        ]
        let activity = [
            ActivityEvent(id: UUID(), kind: .buy, symbol: "BTC/USD", quantity: 1, price: 100, timestamp: .now, orderID: orders[0].id, relatedPositionID: nil, realizedPnL: nil)
        ]

        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let exporter = DefaultCSVExportService(outputDirectory: temp)
        let url = try exporter.exportLedger(orders: orders, activity: activity)
        let text = try String(contentsOf: url)

        XCTAssertTrue(text.contains("timestamp,symbol,event_type,side,quantity,price,gross_value,realized_pnl"))
        XCTAssertTrue(text.contains("BTC/USD"))
    }

    func testOrdersViewModelReceivesUpdatesWhenHistoryChanges() throws {
        let market = AnalyticsTestMarketDataRepository(quote: .init(symbol: "BTC/USD", lastPrice: 100, changePercent: 0, timestamp: .now, source: "test", isSimulated: true))
        let repository = InMemoryPortfolioRepository(marketDataRepository: market, cashBalance: 3_000)
        let analytics = DefaultPortfolioAnalyticsService(repository: repository)
        let viewModel = OrdersViewModel(analyticsService: analytics, csvExportService: DefaultCSVExportService())

        _ = try repository.applyFilledOrder(.init(assetSymbol: "BTC/USD", side: .buy, type: .market, quantity: 1, estimatedPrice: nil, submittedAt: .now, limitPrice: nil, stopPrice: nil), executionPrice: 100, filledAt: .now)

        XCTAssertEqual(viewModel.orders.count, 1)
        XCTAssertEqual(viewModel.activity.count, 1)
    }
}

private final class AnalyticsTestMarketDataRepository: MarketDataRepository {
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
}
