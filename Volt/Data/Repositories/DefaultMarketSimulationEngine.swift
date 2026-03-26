import Combine
import Foundation
internal import os

final class DefaultMarketSimulationEngine: MarketSimulationEngine {
    private let config: PriceSimulationConfig
    private let clock: ClockProviding
    private let volatilityPresetProvider: () -> SimulatorVolatilityPreset
    private let stateLock = NSLock()
    private var prices: [String: Decimal] = [:]
    private var tickTask: Task<Void, Never>?

    private let tickSubject = PassthroughSubject<MarketTick, Never>()
    private let stateSubject = CurrentValueSubject<StreamConnectionState, Never>(.idle)

    var ticksPublisher: AnyPublisher<MarketTick, Never> { tickSubject.eraseToAnyPublisher() }
    var connectionStatePublisher: AnyPublisher<StreamConnectionState, Never> { stateSubject.eraseToAnyPublisher() }

    init(
        config: PriceSimulationConfig = .default,
        clock: ClockProviding = SystemClock(),
        volatilityPresetProvider: @escaping () -> SimulatorVolatilityPreset = { .normal }
    ) {
        self.config = config
        self.clock = clock
        self.volatilityPresetProvider = volatilityPresetProvider
    }

    deinit {
        stop()
    }

    func start(with seedQuotes: [Quote]) {
        reseed(with: seedQuotes)

        stateLock.lock()
        defer { stateLock.unlock() }
        guard tickTask == nil else { return }

        stateSubject.send(.liveSimulated)
        AppLogger.market.info("Simulation engine tick loop started")
        tickTask = Task(priority: .utility) { [weak self] in
            await self?.runTickLoop()
        }
    }

    func stop() {
        stateLock.lock()
        let task = tickTask
        tickTask = nil
        stateLock.unlock()

        task?.cancel()
        stateSubject.send(.idle)
        AppLogger.market.info("Simulation engine tick loop stopped")
    }

    func reseed(with quotes: [Quote]) {
        stateLock.lock()
        prices = Dictionary(uniqueKeysWithValues: quotes.map { ($0.symbol, $0.lastPrice) })
        stateLock.unlock()
    }

    private func runTickLoop() async {
        while Task.isCancelled == false {
            do {
                try await Task.sleep(for: .seconds(config.tickIntervalSeconds))
            } catch {
                break
            }

            if Task.isCancelled { break }
            generateTickBurst()
        }
    }

    private func generateTickBurst() {
        stateLock.lock()
        var nextPrices: [String: Decimal] = [:]
        nextPrices.reserveCapacity(prices.count)
        let existing = prices
        for (symbol, lastPrice) in existing {
            nextPrices[symbol] = simulatePrice(from: lastPrice)
        }
        prices = nextPrices
        stateLock.unlock()

        let now = clock.now
        for (symbol, price) in nextPrices {
            tickSubject.send(MarketTick(symbol: symbol, price: price, timestamp: now, isSimulated: true))
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
        let base: Decimal
        switch config.volatilityProfile {
        case .low: base = 0.5
        case .medium: base = 1.0
        case .high: base = 1.5
        }

        let runtime: Decimal
        switch volatilityPresetProvider() {
        case .calm: runtime = 0.7
        case .normal: runtime = 1.0
        case .aggressive: runtime = 1.4
        }
        return base * runtime
    }
}
