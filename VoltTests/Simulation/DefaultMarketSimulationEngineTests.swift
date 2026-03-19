import Combine
import XCTest
@testable import Volt

final class DefaultMarketSimulationEngineTests: XCTestCase {
    private var cancellables = Set<AnyCancellable>()

    func testSimulationStartsFromSeedAndNonNegative() {
        let config = PriceSimulationConfig(
            maxPercentMovePerTick: 0.002,
            tickIntervalSeconds: 0.05,
            volatilityProfile: .low,
            clampRules: .init(minimumPrice: 0.0001, maximumTickMoveAbsolute: nil)
        )
        let engine = DefaultMarketSimulationEngine(config: config)
        let exp = expectation(description: "Receive simulated ticks")
        exp.expectedFulfillmentCount = 3

        var received: [MarketTick] = []
        engine.ticksPublisher
            .sink { tick in
                received.append(tick)
                exp.fulfill()
            }
            .store(in: &cancellables)

        engine.start(with: [Quote(symbol: "BTC/USD", lastPrice: 100, changePercent: 0, timestamp: Date(), source: "test", isSimulated: false)])

        wait(for: [exp], timeout: 2)
        engine.stop()

        XCTAssertTrue(received.allSatisfy { $0.price >= 0.0001 })
        XCTAssertTrue(received.allSatisfy { $0.symbol == "BTC/USD" })
    }

    func testSimulationRespectsBoundedMovement() {
        let maxPercent: Decimal = 0.001
        let config = PriceSimulationConfig(
            maxPercentMovePerTick: maxPercent,
            tickIntervalSeconds: 0.05,
            volatilityProfile: .low,
            clampRules: .init(minimumPrice: 0.0001, maximumTickMoveAbsolute: nil)
        )
        let engine = DefaultMarketSimulationEngine(config: config)
        let exp = expectation(description: "Receive tick")

        var firstTick: MarketTick?
        engine.ticksPublisher
            .sink { tick in
                firstTick = tick
                exp.fulfill()
            }
            .store(in: &cancellables)

        let seedPrice: Decimal = 100
        engine.start(with: [Quote(symbol: "ETH/USD", lastPrice: seedPrice, changePercent: 0, timestamp: Date(), source: "test", isSimulated: false)])
        wait(for: [exp], timeout: 2)
        engine.stop()

        guard let price = firstTick?.price else {
            XCTFail("Missing first tick")
            return
        }

        let delta = abs(((price - seedPrice) / seedPrice) as NSDecimalNumber).doubleValue
        XCTAssertLessThanOrEqual(delta, (maxPercent as NSDecimalNumber).doubleValue + 0.0001)
    }
}
