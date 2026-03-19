import Combine
import Foundation

final class DefaultMarketSimulationEngine: MarketSimulationEngine {
    private let config: PriceSimulationConfig
    private let clock: ClockProviding
    private var prices: [String: Decimal] = [:]
    private var timerCancellable: AnyCancellable?

    private let tickSubject = PassthroughSubject<MarketTick, Never>()
    private let stateSubject = CurrentValueSubject<StreamConnectionState, Never>(.idle)

    var ticksPublisher: AnyPublisher<MarketTick, Never> { tickSubject.eraseToAnyPublisher() }
    var connectionStatePublisher: AnyPublisher<StreamConnectionState, Never> { stateSubject.eraseToAnyPublisher() }

    init(config: PriceSimulationConfig = .default, clock: ClockProviding = SystemClock()) {
        self.config = config
        self.clock = clock
    }

    func start(with seedQuotes: [Quote]) {
        reseed(with: seedQuotes)
        guard timerCancellable == nil else { return }
        stateSubject.send(.liveSimulated)

        timerCancellable = Timer.publish(every: config.tickIntervalSeconds, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.generateTickBurst()
            }
    }

    func stop() {
        timerCancellable?.cancel()
        timerCancellable = nil
        stateSubject.send(.idle)
    }

    func reseed(with quotes: [Quote]) {
        quotes.forEach { prices[$0.symbol] = $0.lastPrice }
    }

    private func generateTickBurst() {
        for (symbol, lastPrice) in prices {
            let newPrice = simulatePrice(from: lastPrice)
            prices[symbol] = newPrice
            tickSubject.send(MarketTick(symbol: symbol, price: newPrice, timestamp: clock.now, isSimulated: true))
        }
    }

    private func simulatePrice(from lastPrice: Decimal) -> Decimal {
        let maxMove = config.maxPercentMovePerTick
        let randomFactor = Decimal(Double.random(in: -1...1))
        var percentMove = randomFactor * maxMove * profileMultiplier

        if percentMove > maxMove { percentMove = maxMove }
        if percentMove < -maxMove { percentMove = -maxMove }

        let candidate = lastPrice * (1 + percentMove)
        if let absoluteLimit = config.clampRules.maximumTickMoveAbsolute {
            let delta = candidate - lastPrice
            if delta > absoluteLimit { return max(lastPrice + absoluteLimit, config.clampRules.minimumPrice) }
            if delta < -absoluteLimit { return max(lastPrice - absoluteLimit, config.clampRules.minimumPrice) }
        }

        return max(candidate, config.clampRules.minimumPrice)
    }

    private var profileMultiplier: Decimal {
        switch config.volatilityProfile {
        case .low: return 0.5
        case .medium: return 1.0
        case .high: return 1.5
        }
    }
}
