import Combine
import Foundation

protocol MarketDataRepository {
    var quotesPublisher: AnyPublisher<[Quote], Never> { get }
    var tickPublisher: AnyPublisher<MarketTick, Never> { get }
    var connectionStatePublisher: AnyPublisher<StreamConnectionState, Never> { get }
    var seedingStatePublisher: AnyPublisher<MarketSeedingState, Never> { get }

    func start() async
    func quote(for symbol: String) -> Quote?
    func quotePublisher(for symbol: String) -> AnyPublisher<Quote?, Never>
    func watchlistQuotes(for symbols: [String]) -> AnyPublisher<[Quote], Never>
    func fetchRecentCandles(symbol: String, outputSize: Int) async throws -> [Candle]
}

enum MarketSeedingState: Equatable, Sendable {
    case idle
    case seeding
    case ready
    case failed(String)
    case fallbackMocked(String)
}
