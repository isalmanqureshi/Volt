import Combine
import XCTest
@testable import Volt

@MainActor
final class Milestone7LifecycleAndAnalyticsTests: XCTestCase {
    func testForegroundResumeReseedsAfterThreshold() async {
        let seedProvider = CountingSeedProvider()
        let engine = RecordingSimulationEngine()
        let repository = DefaultMarketDataRepository(
            seedProvider: seedProvider,
            historicalDataProvider: MockHistoricalDataProvider(),
            simulationEngine: engine,
            symbols: ["BTC/USD"],
            reseedInterval: 60
        )

        await repository.start()
        XCTAssertEqual(seedProvider.fetchCount, 1)
        XCTAssertEqual(engine.startCalls, 1)

        repository.handleBackgroundTransition(at: .now.addingTimeInterval(-120))
        await repository.handleForegroundResume(at: .now)

        XCTAssertEqual(seedProvider.fetchCount, 2)
        XCTAssertEqual(engine.reseedCalls, 1)
        XCTAssertEqual(engine.startCalls, 1)
    }

    func testSnapshotCheckpointPersistsAndReloads() throws {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let market = AnalyticsTestMarketDataRepository(quote: .init(symbol: "BTC/USD", lastPrice: 100, changePercent: 0, timestamp: .now, source: "test", isSimulated: true))
        let portfolio = InMemoryPortfolioRepository(marketDataRepository: market, cashBalance: 10_000)
        let store = FileBackedAccountSnapshotStore(baseDirectory: temp)

        let service = DefaultAccountSnapshotCheckpointService(
            portfolioRepository: portfolio,
            environmentProvider: AppEnvironmentProvider(currentEnvironment: .mock),
            snapshotStore: store,
            minimumCheckpointInterval: 0
        )

        service.checkpoint(trigger: .appLaunch)
        XCTAssertEqual(service.checkpoints.count, 1)

        let reloaded = try store.loadCheckpoints()
        XCTAssertEqual(reloaded.count, 1)
        XCTAssertEqual(reloaded[0].trigger, .appLaunch)
    }

    func testDailyBucketsAndDistributionUseRealizedHistory() throws {
        let now = Date()
        let market = AnalyticsTestMarketDataRepository(quote: .init(symbol: "BTC/USD", lastPrice: 100, changePercent: 0, timestamp: now, source: "test", isSimulated: true))
        let repository = InMemoryPortfolioRepository(marketDataRepository: market, cashBalance: 10_000)

        _ = try repository.applyFilledOrder(.init(assetSymbol: "BTC/USD", side: .buy, type: .market, quantity: 2, estimatedPrice: nil, submittedAt: now.addingTimeInterval(-200_000), limitPrice: nil, stopPrice: nil), executionPrice: 100, filledAt: now.addingTimeInterval(-200_000))
        _ = try repository.applyFilledOrder(.init(assetSymbol: "BTC/USD", side: .sell, type: .market, quantity: 1, estimatedPrice: nil, submittedAt: now.addingTimeInterval(-170_000), limitPrice: nil, stopPrice: nil), executionPrice: 130, filledAt: now.addingTimeInterval(-170_000))
        _ = try repository.applyFilledOrder(.init(assetSymbol: "BTC/USD", side: .sell, type: .market, quantity: 1, estimatedPrice: nil, submittedAt: now.addingTimeInterval(-80_000), limitPrice: nil, stopPrice: nil), executionPrice: 90, filledAt: now.addingTimeInterval(-80_000))

        let service = DefaultPortfolioAnalyticsService(repository: repository)
        XCTAssertEqual(service.currentDailyPerformance.count, 2)
        XCTAssertEqual(service.currentRealizedDistribution.first(where: { $0.outcome == .gain })?.count, 1)
        XCTAssertEqual(service.currentRealizedDistribution.first(where: { $0.outcome == .loss })?.count, 1)
    }

    func testExportPresetWritesExpectedHeaders() throws {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let exporter = DefaultCSVExportService(outputDirectory: temp)
        let orders = [OrderRecord(id: UUID(), symbol: "BTC/USD", side: .buy, type: .market, quantity: 1, executedPrice: 100, grossValue: 100, submittedAt: .now, executedAt: .now, status: .filled, source: .simulated, linkedPositionID: nil)]

        let url = try exporter.export(
            preset: .orderHistoryOnly,
            orders: orders,
            activity: [],
            summary: .empty
        )

        let text = try String(contentsOf: url)
        XCTAssertTrue(text.contains("timestamp,symbol,side,type,quantity,price,gross_value"))
    }
}

private final class CountingSeedProvider: MarketSeedProvider {
    private(set) var fetchCount = 0

    func fetchInitialQuotes(for symbols: [String]) async throws -> [Quote] {
        fetchCount += 1
        return symbols.map {
            Quote(symbol: $0, lastPrice: 100, changePercent: 0, timestamp: .now, source: "test", isSimulated: false)
        }
    }
}

private final class RecordingSimulationEngine: MarketSimulationEngine {
    private(set) var startCalls = 0
    private(set) var reseedCalls = 0

    var ticksPublisher: AnyPublisher<MarketTick, Never> { Empty().eraseToAnyPublisher() }
    var connectionStatePublisher: AnyPublisher<StreamConnectionState, Never> { Just(.liveSimulated).eraseToAnyPublisher() }

    func start(with seedQuotes: [Quote]) { startCalls += 1 }
    func stop() {}
    func reseed(with quotes: [Quote]) { reseedCalls += 1 }
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
