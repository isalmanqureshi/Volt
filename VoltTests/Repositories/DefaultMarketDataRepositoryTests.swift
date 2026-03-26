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
}
