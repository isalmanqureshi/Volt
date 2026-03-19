import Combine
import Foundation
internal import os

final class DefaultMarketDataRepository: MarketDataRepository {
    private let seedProvider: MarketSeedProvider
    private let historicalDataProvider: HistoricalDataProvider
    private let simulationEngine: MarketSimulationEngine
    private let symbols: [String]
    private let defaultCandleOutputSize: Int
    private var cancellables = Set<AnyCancellable>()
    private var hasSeeded = false

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
        defaultCandleOutputSize: Int = 90
    ) {
        self.seedProvider = seedProvider
        self.historicalDataProvider = historicalDataProvider
        self.simulationEngine = simulationEngine
        self.symbols = symbols
        self.defaultCandleOutputSize = defaultCandleOutputSize
        bindSimulation()
    }

    func start() async {
        guard hasSeeded == false else {
            AppLogger.market.debug("Seed skipped: repository already active")
            return
        }
        seedingStateSubject.send(.seeding)
        hasSeeded = true
        do {
            let initialQuotes = try await seedProvider.fetchInitialQuotes(for: symbols)
            quotesSubject.send(initialQuotes)
            simulationEngine.start(with: initialQuotes)
            seedingStateSubject.send(.ready)
            AppLogger.market.info("Simulation started from provider seed quotes")
        } catch {
            AppLogger.market.error("Failed to fetch seed quotes. Falling back to baseline prices. Error: \(error.localizedDescription, privacy: .public)")
            let fallback = symbols.map { symbol in
                Quote(symbol: symbol, lastPrice: defaultFallbackPrice(for: symbol), changePercent: 0, timestamp: Date(), source: "fallback-mock", isSimulated: false)
            }
            quotesSubject.send(fallback)
            simulationEngine.start(with: fallback)
            seedingStateSubject.send(.fallbackMocked(error.localizedDescription))
            AppLogger.market.warning("Fallback seed quotes activated")
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
            AppLogger.market.info("Candle fetch succeeded for \(symbol, privacy: .public)")
            return candles
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
