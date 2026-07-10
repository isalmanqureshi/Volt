import Combine
import XCTest
@testable import Volt

final class DefaultMarketDataRepositoryTests: XCTestCase {
    private var cancellables = Set<AnyCancellable>()

    func testSharedRepositoryPublishesAllSymbolsFromSingleEngine() async {
        let engine = DefaultMarketSimulationEngine(
            config: PriceSimulationConfig(maxPercentMovePerTick: 0.001, tickIntervalSeconds: 0.05, volatilityProfile: .low, clampRules: .init(minimumPrice: 0.0001, maximumTickMoveAbsolute: nil))
        )
        let repository = DefaultMarketDataRepository(
            seedProvider: MockMarketSeedProvider(),
            historicalDataProvider: MockHistoricalDataProvider(),
            simulationEngine: engine,
            symbols: ["BTC/USD", "ETH/USD", "SOL/USD"]
        )

        let exp = expectation(description: "quotes update")
        repository.quotesPublisher
            .dropFirst()
            .sink { quotes in
                if quotes.count == 3, quotes.allSatisfy({ $0.isSimulated }) {
                    exp.fulfill()
                }
            }
            .store(in: &cancellables)

        await repository.start()
        await fulfillment(of: [exp], timeout: 3)
        engine.stop()
    }

    func testTickBurstProducesSingleQuotesEmission() async {
        let engine = ScriptedSimulationEngine()
        let repository = DefaultMarketDataRepository(
            seedProvider: MockMarketSeedProvider(),
            historicalDataProvider: MockHistoricalDataProvider(),
            simulationEngine: engine,
            symbols: ["BTC/USD", "ETH/USD", "SOL/USD"]
        )
        await repository.start()

        var emissions: [[Quote]] = []
        repository.quotesPublisher
            .dropFirst() // skip the CurrentValueSubject replay
            .sink { emissions.append($0) }
            .store(in: &cancellables)

        let now = Date()
        engine.emitBatch([
            MarketTick(symbol: "BTC/USD", price: 70_000, timestamp: now, isSimulated: true),
            MarketTick(symbol: "ETH/USD", price: 3_600, timestamp: now, isSimulated: true),
            MarketTick(symbol: "SOL/USD", price: 190, timestamp: now, isSimulated: true)
        ])

        XCTAssertEqual(emissions.count, 1, "A tick burst must publish once, not once per symbol")
        let prices = Dictionary(uniqueKeysWithValues: emissions[0].map { ($0.symbol, $0.lastPrice) })
        XCTAssertEqual(prices["BTC/USD"], 70_000)
        XCTAssertEqual(prices["ETH/USD"], 3_600)
        XCTAssertEqual(prices["SOL/USD"], 190)
    }

    func testSingleTickEngineStillUpdatesQuotesViaDefaultBatchAdapter() async {
        let engine = ScriptedSimulationEngine(useDefaultBatchAdapter: true)
        let repository = DefaultMarketDataRepository(
            seedProvider: MockMarketSeedProvider(),
            historicalDataProvider: MockHistoricalDataProvider(),
            simulationEngine: engine,
            symbols: ["BTC/USD"]
        )
        await repository.start()

        engine.emitTick(MarketTick(symbol: "BTC/USD", price: 71_500, timestamp: Date(), isSimulated: true))

        XCTAssertEqual(repository.quote(for: "BTC/USD")?.lastPrice, 71_500)
    }
}

/// Engine whose ticks are driven by the test instead of a timer. With
/// `useDefaultBatchAdapter` it only emits per-symbol ticks, exercising the
/// protocol extension's single-tick batch adaptation.
private final class ScriptedSimulationEngine: MarketSimulationEngine {
    private let tickSubject = PassthroughSubject<MarketTick, Never>()
    private let batchSubject = PassthroughSubject<[MarketTick], Never>()
    private let useDefaultBatchAdapter: Bool

    init(useDefaultBatchAdapter: Bool = false) {
        self.useDefaultBatchAdapter = useDefaultBatchAdapter
    }

    var ticksPublisher: AnyPublisher<MarketTick, Never> { tickSubject.eraseToAnyPublisher() }
    var tickBatchesPublisher: AnyPublisher<[MarketTick], Never> {
        useDefaultBatchAdapter
            ? ticksPublisher.map { [$0] }.eraseToAnyPublisher()
            : batchSubject.eraseToAnyPublisher()
    }
    var connectionStatePublisher: AnyPublisher<StreamConnectionState, Never> { Just(.liveSimulated).eraseToAnyPublisher() }

    func start(with seedQuotes: [Quote]) {}
    func stop() {}
    func reseed(with quotes: [Quote]) {}

    func emitBatch(_ ticks: [MarketTick]) { batchSubject.send(ticks) }
    func emitTick(_ tick: MarketTick) { tickSubject.send(tick) }
}
