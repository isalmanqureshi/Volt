import Combine
import XCTest
@testable import Volt

final class Milestone2RepositoryAndPortfolioTests: XCTestCase {
    private var cancellables = Set<AnyCancellable>()

    func testRepositoryDoesNotReseedIfAlreadyStarted() async {
        let provider = CountingSeedProvider()
        let repository = DefaultMarketDataRepository(
            seedProvider: provider,
            historicalDataProvider: MockHistoricalDataProvider(),
            simulationEngine: DefaultMarketSimulationEngine(config: .init(maxPercentMovePerTick: 0.0001, tickIntervalSeconds: 10, volatilityProfile: .low, clampRules: .init(minimumPrice: 0.0001, maximumTickMoveAbsolute: nil))),
            symbols: ["BTC/USD"]
        )

        await repository.start()
        await repository.start()

        XCTAssertEqual(provider.fetchCount, 1)
    }

    func testRepositoryFallsBackWhenSeedFails() async {
        let repository = DefaultMarketDataRepository(
            seedProvider: FailingSeedProvider(),
            historicalDataProvider: MockHistoricalDataProvider(),
            simulationEngine: DefaultMarketSimulationEngine(config: .init(maxPercentMovePerTick: 0.0001, tickIntervalSeconds: 10, volatilityProfile: .low, clampRules: .init(minimumPrice: 0.0001, maximumTickMoveAbsolute: nil))),
            symbols: ["BTC/USD", "ETH/USD"]
        )

        await repository.start()

        let quotes = await collectValue(from: repository.quotesPublisher)
        XCTAssertEqual(quotes.count, 2)
        XCTAssertTrue(quotes.allSatisfy { $0.source == "fallback-mock" })
    }

    func testPortfolioRecalculatesUnrealizedPnLFromQuotes() async {
        let market = PassthroughMarketRepository()
        let repository = InMemoryPortfolioRepository(marketDataRepository: market)

        market.push(quotes: [
            Quote(symbol: "BTC/USD", lastPrice: 68_000, changePercent: 0, timestamp: .now, source: "test", isSimulated: true),
            Quote(symbol: "ETH/USD", lastPrice: 3_700, changePercent: 0, timestamp: .now, source: "test", isSimulated: true),
            Quote(symbol: "SOL/USD", lastPrice: 165, changePercent: 0, timestamp: .now, source: "test", isSimulated: true)
        ])

        let positions = await collectValue(from: repository.positionsPublisher)
        XCTAssertEqual(positions.first(where: { $0.symbol == "BTC/USD" })?.currentPrice, 68_000)

        let summary = await collectValue(from: repository.summaryPublisher)
        XCTAssertNotEqual(summary.unrealizedPnL, 0)
    }

    private func collectValue<T>(from publisher: AnyPublisher<T, Never>) async -> T {
        await withCheckedContinuation { continuation in
            var cancellable: AnyCancellable?
            cancellable = publisher.first().sink { value in
                continuation.resume(returning: value)
                _ = cancellable
            }
        }
    }
}

private final class CountingSeedProvider: MarketSeedProvider {
    private(set) var fetchCount = 0

    func fetchInitialQuotes(for symbols: [String]) async throws -> [Quote] {
        fetchCount += 1
        return symbols.map { Quote(symbol: $0, lastPrice: 100, changePercent: 0, timestamp: .now, source: "count", isSimulated: false) }
    }
}

private struct FailingSeedProvider: MarketSeedProvider {
    func fetchInitialQuotes(for symbols: [String]) async throws -> [Quote] {
        throw URLError(.badServerResponse)
    }
}

private final class PassthroughMarketRepository: MarketDataRepository {
    let quotes = CurrentValueSubject<[Quote], Never>([])

    var quotesPublisher: AnyPublisher<[Quote], Never> { quotes.eraseToAnyPublisher() }
    var tickPublisher: AnyPublisher<MarketTick, Never> { Empty().eraseToAnyPublisher() }
    var connectionStatePublisher: AnyPublisher<StreamConnectionState, Never> { Just(.liveSimulated).eraseToAnyPublisher() }
    var seedingStatePublisher: AnyPublisher<MarketSeedingState, Never> { Just(.ready).eraseToAnyPublisher() }

    func start() async {}
    func quote(for symbol: String) -> Quote? { quotes.value.first { $0.symbol == symbol } }
    func quotePublisher(for symbol: String) -> AnyPublisher<Quote?, Never> {
        quotesPublisher.map { list in list.first(where: { $0.symbol == symbol }) }.eraseToAnyPublisher()
    }
    func watchlistQuotes(for symbols: [String]) -> AnyPublisher<[Quote], Never> {
        quotesPublisher.map { list in list.filter { symbols.contains($0.symbol) } }.eraseToAnyPublisher()
    }
    func fetchRecentCandles(symbol: String, outputSize: Int) async throws -> [Candle] { [] }

    func push(quotes: [Quote]) {
        self.quotes.send(quotes)
    }
}
