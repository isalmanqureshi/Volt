import Combine
import XCTest
@testable import Volt

@MainActor
final class Milestone7LifecycleAndAnalyticsTests: XCTestCase {
    func testConcurrentStartOnlyRunsSingleSeedAndSimulationStart() async {
        let seedProvider = DelayedCountingSeedProvider(delayNanoseconds: 150_000_000)
        let engine = RecordingSimulationEngine()
        let repository = DefaultMarketDataRepository(
            seedProvider: seedProvider,
            historicalDataProvider: MockHistoricalDataProvider(),
            simulationEngine: engine,
            symbols: ["BTC/USD"]
        )

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<8 {
                group.addTask { await repository.start() }
            }
            await group.waitForAll()
        }

        let fetchCount = await seedProvider.fetchCount
        XCTAssertEqual(fetchCount, 1)
        XCTAssertEqual(engine.startCalls, 1)
        XCTAssertEqual(engine.reseedCalls, 0)
    }

    func testFailedStartupClearsInFlightAndRetrySucceeds() async {
        let seedProvider = DelayedCountingSeedProvider(delayNanoseconds: 2_000_000_000)
        let engine = RecordingSimulationEngine()
        let repository = DefaultMarketDataRepository(
            seedProvider: seedProvider,
            historicalDataProvider: MockHistoricalDataProvider(),
            simulationEngine: engine,
            symbols: ["BTC/USD"]
        )

        let task = Task { await repository.start() }
        task.cancel()
        _ = await task.result

        XCTAssertEqual(await seedProvider.fetchCount, 1)
        XCTAssertEqual(engine.startCalls, 0)

        await repository.start()
        XCTAssertEqual(await seedProvider.fetchCount, 2)
        XCTAssertEqual(engine.startCalls, 1)
    }

    func testOrderExecutionCheckpointUsesPostTradeSummaryValues() throws {
        let market = AnalyticsTestMarketDataRepository(quote: .init(symbol: "BTC/USD", lastPrice: 100, changePercent: 0, timestamp: .now, source: "test", isSimulated: true))
        let portfolio = InMemoryPortfolioRepository(marketDataRepository: market, cashBalance: 10_000)
        let checkpointService = DefaultAccountSnapshotCheckpointService(
            portfolioRepository: portfolio,
            environmentProvider: AppEnvironmentProvider(currentEnvironment: .mock),
            snapshotStore: InMemorySnapshotStore(),
            minimumCheckpointInterval: 0
        )
        let trading = DefaultTradingSimulationService(
            marketDataRepository: market,
            portfolioRepository: portfolio,
            checkpointService: checkpointService,
            supportedSymbols: ["BTC/USD"]
        )

        _ = try trading.placeOrder(
            OrderDraft(
                assetSymbol: "BTC/USD",
                side: .buy,
                type: .market,
                quantity: 1,
                estimatedPrice: 100,
                submittedAt: .now,
                limitPrice: nil,
                stopPrice: nil
            )
        )

        guard let checkpoint = checkpointService.checkpoints.last else {
            XCTFail("Missing order execution checkpoint")
            return
        }
        XCTAssertEqual(checkpoint.trigger, .orderExecution)
        XCTAssertEqual(checkpoint.cashBalance, 9_900)
        XCTAssertEqual(checkpoint.positionsMarketValue, 100)
        XCTAssertEqual(checkpoint.totalEquity, 10_000)
    }

    func testPerformancePointsFilterToActiveEnvironment() {
        let now = Date()
        let checkpoints: [AccountSnapshotCheckpoint] = [
            .init(timestamp: now.addingTimeInterval(-120), cashBalance: 1_000, positionsMarketValue: 0, unrealizedPnL: 0, realizedPnL: 0, totalEquity: 1_000, openPositionsCount: 0, environment: .mock, trigger: .appLaunch),
            .init(timestamp: now.addingTimeInterval(-60), cashBalance: 2_000, positionsMarketValue: 0, unrealizedPnL: 0, realizedPnL: 0, totalEquity: 2_000, openPositionsCount: 0, environment: .twelveDataSeededSimulation, trigger: .appLaunch)
        ]
        let checkpointService = StubCheckpointService(checkpoints: checkpoints)
        let repository = InMemoryPortfolioRepository(marketDataRepository: AnalyticsTestMarketDataRepository(quote: .init(symbol: "BTC/USD", lastPrice: 100, changePercent: 0, timestamp: now, source: "test", isSimulated: true)), cashBalance: 500)

        let analytics = DefaultPortfolioAnalyticsService(
            repository: repository,
            checkpointService: checkpointService,
            environmentProvider: AppEnvironmentProvider(currentEnvironment: .twelveDataSeededSimulation),
            nowProvider: { now }
        )

        XCTAssertTrue(analytics.currentPerformance.contains(where: { $0.equity == 2_000 }))
        XCTAssertFalse(analytics.currentPerformance.contains(where: { $0.equity == 1_000 }))
    }

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

        let persisted = expectation(description: "checkpoint persisted")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { persisted.fulfill() }
        wait(for: [persisted], timeout: 1.0)

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


    func testQuoteOnlyUpdatesDoNotTriggerStructuralAnalyticsRecompute() {
        let now = Date()
        let market = AnalyticsTestMarketDataRepository(quote: .init(symbol: "BTC/USD", lastPrice: 100, changePercent: 0, timestamp: now, source: "test", isSimulated: true))
        let repository = InMemoryPortfolioRepository(marketDataRepository: market, cashBalance: 10_000)
        let analytics = DefaultPortfolioAnalyticsService(repository: repository, nowProvider: { now })

        let idle = expectation(description: "analytics settled")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { idle.fulfill() }
        wait(for: [idle], timeout: 1.0)

        let structuralBaseline = analytics.structuralRecomputeCount
        let summaryBaseline = analytics.summaryOnlyUpdateCount

        market.emit(quotes: [.init(symbol: "BTC/USD", lastPrice: 101, changePercent: 0, timestamp: now.addingTimeInterval(1), source: "test", isSimulated: true)])
        market.emit(quotes: [.init(symbol: "BTC/USD", lastPrice: 102, changePercent: 0, timestamp: now.addingTimeInterval(2), source: "test", isSimulated: true)])

        let updates = expectation(description: "summary updates propagated")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { updates.fulfill() }
        wait(for: [updates], timeout: 1.0)

        XCTAssertEqual(analytics.structuralRecomputeCount, structuralBaseline)
        XCTAssertGreaterThan(analytics.summaryOnlyUpdateCount, summaryBaseline)
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

private actor DelayedCountingSeedProvider: MarketSeedProvider {
    private let delayNanoseconds: UInt64
    private(set) var fetchCount = 0

    init(delayNanoseconds: UInt64) {
        self.delayNanoseconds = delayNanoseconds
    }

    func fetchInitialQuotes(for symbols: [String]) async throws -> [Quote] {
        fetchCount += 1
        try await Task.sleep(nanoseconds: delayNanoseconds)
        return symbols.map {
            Quote(symbol: $0, lastPrice: 100, changePercent: 0, timestamp: .now, source: "test", isSimulated: false)
        }
    }
}

private struct StubCheckpointService: AccountSnapshotCheckpointing {
    let checkpoints: [AccountSnapshotCheckpoint]
    func checkpoint(trigger: AccountSnapshotCheckpoint.Trigger) {}
}

private final class InMemorySnapshotStore: AccountSnapshotStore {
    private var value: [AccountSnapshotCheckpoint] = []
    func loadCheckpoints() throws -> [AccountSnapshotCheckpoint] { value }
    func saveCheckpoints(_ checkpoints: [AccountSnapshotCheckpoint]) throws { value = checkpoints }
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

    func emit(quotes: [Quote]) {
        quotesSubject.send(quotes)
    }
}
