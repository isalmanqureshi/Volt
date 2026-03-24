import Combine
import Foundation
internal import os

final class DefaultMarketDataRepository: MarketDataRepository {
    private actor StartupState {
        private(set) var hasSeeded = false
        private var activePipeline: Task<Void, Never>?

        func hasCompletedSeed() -> Bool { hasSeeded }

        func runPipelineIfNeeded(
            forceReseed: Bool,
            operation: @escaping (_ hasSeeded: Bool) async -> Bool
        ) async {
            if forceReseed == false, hasSeeded {
                return
            }

            if let activePipeline {
                await activePipeline.value
                return
            }

            let seededBeforeRun = hasSeeded
            let task = Task {
                let success = await operation(seededBeforeRun)
                await self.finishPipeline(success: success)
            }
            activePipeline = task
            await task.value
        }

        private func finishPipeline(success: Bool) {
            if success {
                hasSeeded = true
            }
            activePipeline = nil
        }
    }

    private let seedProvider: MarketSeedProvider
    private let historicalDataProvider: HistoricalDataProvider
    private let simulationEngine: MarketSimulationEngine
    private let symbols: [String]
    private let defaultCandleOutputSize: Int
    private let reseedInterval: TimeInterval
    private var cancellables = Set<AnyCancellable>()
    private let startupState = StartupState()
    private var lastBackgroundDate: Date?

    private let quotesSubject = CurrentValueSubject<[Quote], Never>([])
    private let seedingStateSubject = CurrentValueSubject<MarketSeedingState, Never>(.idle)

    var quotesPublisher: AnyPublisher<[Quote], Never> { quotesSubject.eraseToAnyPublisher() }
    var tickPublisher: AnyPublisher<MarketTick, Never> { simulationEngine.ticksPublisher }
    var connectionStatePublisher: AnyPublisher<StreamConnectionState, Never> { simulationEngine.connectionStatePublisher }
    var seedingStatePublisher: AnyPublisher<MarketSeedingState, Never> { seedingStateSubject.eraseToAnyPublisher() }

    init(
        seedProvider: MarketSeedProvider,
        historicalDataProvider: HistoricalDataProvider,
        simulationEngine: MarketSimulationEngine,
        symbols: [String],
        defaultCandleOutputSize: Int = 90,
        reseedInterval: TimeInterval = 60 * 8
    ) {
        self.seedProvider = seedProvider
        self.historicalDataProvider = historicalDataProvider
        self.simulationEngine = simulationEngine
        self.symbols = symbols
        self.defaultCandleOutputSize = defaultCandleOutputSize
        self.reseedInterval = reseedInterval
        bindSimulation()
    }

    func start() async {
        await runSeedPipeline(reason: "cold-launch", forceReseed: false)
    }

    func handleForegroundResume(at date: Date) async {
        AppLogger.market.info("Lifecycle foreground resume received")
        let hasCompletedSeed = await startupState.hasCompletedSeed()
        guard hasCompletedSeed else {
            await start()
            return
        }

        if let lastBackgroundDate {
            let elapsed = date.timeIntervalSince(lastBackgroundDate)
            AppLogger.market.debug("Resume reseed elapsed=\(elapsed, privacy: .public)s")
            if elapsed >= reseedInterval {
                await runSeedPipeline(reason: "resume-stale", forceReseed: true)
            }
        }

        lastBackgroundDate = nil
    }

    func handleBackgroundTransition(at date: Date) {
        lastBackgroundDate = date
        AppLogger.market.info("Lifecycle background transition recorded")
    }

    func manualRefresh() async {
        await runSeedPipeline(reason: "manual-refresh", forceReseed: true)
    }

    private func runSeedPipeline(reason: String, forceReseed: Bool) async {
        await startupState.runPipelineIfNeeded(forceReseed: forceReseed) { [weak self] hadSeededBeforeRun in
            guard let self else { return false }
            AppLogger.market.info("Seed pipeline started reason=\(reason, privacy: .public) seededBeforeRun=\(hadSeededBeforeRun, privacy: .public)")
            let success = await self.seedAndStart(reason: reason, forceReseed: forceReseed, hadSeededBeforeRun: hadSeededBeforeRun)
            if success {
                AppLogger.market.info("Seed pipeline finished reason=\(reason, privacy: .public)")
            } else {
                AppLogger.market.warning("Seed pipeline failed reason=\(reason, privacy: .public)")
            }
            return success
        }
    }

    private func seedAndStart(reason: String, forceReseed: Bool, hadSeededBeforeRun: Bool) async -> Bool {
        guard symbols.isEmpty == false else {
            AppLogger.market.error("Seeding skipped: no configured symbols")
            seedingStateSubject.send(.failed("no-symbols"))
            return false
        }

        seedingStateSubject.send(.seeding)
        do {
            let initialQuotes = try await seedProvider.fetchInitialQuotes(for: symbols)
            quotesSubject.send(initialQuotes)
            if hadSeededBeforeRun && forceReseed {
                simulationEngine.reseed(with: initialQuotes)
            } else {
                simulationEngine.start(with: initialQuotes)
            }
            seedingStateSubject.send(.ready)
            AppLogger.market.info("Simulation seeded reason=\(reason, privacy: .public)")
            return true
        } catch {
            if error is CancellationError {
                seedingStateSubject.send(.failed("cancelled"))
                AppLogger.market.warning("Seed pipeline cancelled reason=\(reason, privacy: .public)")
                return false
            }
            AppLogger.market.error("Failed to fetch seed quotes. Falling back to baseline prices. Error: \(error.localizedDescription, privacy: .public)")
            let fallback = symbols.map { symbol in
                Quote(symbol: symbol, lastPrice: defaultFallbackPrice(for: symbol), changePercent: 0, timestamp: Date(), source: "fallback-mock", isSimulated: false)
            }
            quotesSubject.send(fallback)
            if hadSeededBeforeRun && forceReseed {
                simulationEngine.reseed(with: fallback)
            } else {
                simulationEngine.start(with: fallback)
            }
            seedingStateSubject.send(.fallbackMocked(error.localizedDescription))
            AppLogger.market.warning("Fallback seed quotes activated reason=\(reason, privacy: .public)")
            return true
        }
    }

    func quote(for symbol: String) -> Quote? {
        quotesSubject.value.first(where: { $0.symbol == symbol })
    }

    func quotePublisher(for symbol: String) -> AnyPublisher<Quote?, Never> {
        quotesPublisher
            .map { quotes in quotes.first(where: { $0.symbol == symbol }) }
            .eraseToAnyPublisher()
    }

    func watchlistQuotes(for symbols: [String]) -> AnyPublisher<[Quote], Never> {
        quotesPublisher
            .map { quotes in quotes.filter { symbols.contains($0.symbol) } }
            .eraseToAnyPublisher()
    }

    func fetchRecentCandles(symbol: String, outputSize: Int) async throws -> [Candle] {
        let effectiveOutputSize = outputSize > 0 ? outputSize : defaultCandleOutputSize
        AppLogger.market.info("Candle fetch started for \(symbol, privacy: .public)")
        do {
            let candles = try await historicalDataProvider.fetchRecentCandles(symbol: symbol, interval: "1min", outputSize: effectiveOutputSize)
            let sortedCandles = candles.sorted(by: { $0.timestamp < $1.timestamp })
            AppLogger.market.info("Candle fetch succeeded for \(symbol, privacy: .public)")
            return sortedCandles
        } catch {
            AppLogger.market.error("Candle fetch failed for \(symbol, privacy: .public): \(error.localizedDescription, privacy: .public)")
            throw error
        }
    }

    private func bindSimulation() {
        simulationEngine.ticksPublisher
            .sink { [weak self] tick in
                guard let self else { return }
                var quotes = self.quotesSubject.value
                if let index = quotes.firstIndex(where: { $0.symbol == tick.symbol }) {
                    let existing = quotes[index]
                    quotes[index] = Quote(
                        symbol: tick.symbol,
                        lastPrice: tick.price,
                        changePercent: existing.changePercent,
                        timestamp: tick.timestamp,
                        source: existing.source,
                        isSimulated: tick.isSimulated
                    )
                    self.quotesSubject.send(quotes)
                }
            }
            .store(in: &cancellables)
    }

    private func defaultFallbackPrice(for symbol: String) -> Decimal {
        switch symbol {
        case "BTC/USD": return 68_500
        case "ETH/USD": return 3_500
        case "SOL/USD": return 180
        case "DOGE/USD": return 0.18
        default: return 100
        }
    }
}
