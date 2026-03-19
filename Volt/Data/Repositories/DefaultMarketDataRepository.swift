import Combine
import Foundation
internal import os

final class DefaultMarketDataRepository: MarketDataRepository {
    private let seedProvider: MarketSeedProvider
    private let simulationEngine: MarketSimulationEngine
    private let symbols: [String]
    private var cancellables = Set<AnyCancellable>()

    private let quotesSubject = CurrentValueSubject<[Quote], Never>([])

    var quotesPublisher: AnyPublisher<[Quote], Never> { quotesSubject.eraseToAnyPublisher() }
    var tickPublisher: AnyPublisher<MarketTick, Never> { simulationEngine.ticksPublisher }
    var connectionStatePublisher: AnyPublisher<StreamConnectionState, Never> { simulationEngine.connectionStatePublisher }

    init(seedProvider: MarketSeedProvider, simulationEngine: MarketSimulationEngine, symbols: [String]) {
        self.seedProvider = seedProvider
        self.simulationEngine = simulationEngine
        self.symbols = symbols
        bindSimulation()
    }

    func start() async {
        do {
            let initialQuotes = try await seedProvider.fetchInitialQuotes(for: symbols)
            quotesSubject.send(initialQuotes)
            simulationEngine.start(with: initialQuotes)
        } catch {
            AppLogger.market.error("Failed to fetch seed quotes. Falling back to baseline prices. Error: \(error.localizedDescription, privacy: .public)")
            let fallback = symbols.map { symbol in
                Quote(symbol: symbol, lastPrice: 100, changePercent: 0, timestamp: Date(), source: "fallback", isSimulated: false)
            }
            quotesSubject.send(fallback)
            simulationEngine.start(with: fallback)
        }
    }

    func quote(for symbol: String) -> Quote? {
        quotesSubject.value.first(where: { $0.symbol == symbol })
    }

    func watchlistQuotes(for symbols: [String]) -> AnyPublisher<[Quote], Never> {
        quotesPublisher
            .map { quotes in quotes.filter { symbols.contains($0.symbol) } }
            .eraseToAnyPublisher()
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
}
