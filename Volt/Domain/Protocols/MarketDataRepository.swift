import Combine
import Foundation

protocol MarketDataRepository {
    var quotesPublisher: AnyPublisher<[Quote], Never> { get }
    var tickPublisher: AnyPublisher<MarketTick, Never> { get }
    var connectionStatePublisher: AnyPublisher<StreamConnectionState, Never> { get }
    var seedingStatePublisher: AnyPublisher<MarketSeedingState, Never> { get }

    func start() async
    func handleForegroundResume(at date: Date) async
    func handleBackgroundTransition(at date: Date)
    func manualRefresh() async
    func quote(for symbol: String) -> Quote?
    func quotePublisher(for symbol: String) -> AnyPublisher<Quote?, Never>
    func watchlistQuotes(for symbols: [String]) -> AnyPublisher<[Quote], Never>
    func fetchRecentCandles(symbol: String, outputSize: Int) async throws -> [Candle]
}

enum MarketDataRefreshError: LocalizedError {
    case noSymbols
    case refreshFailed(String)

    var errorDescription: String? {
        switch self {
        case .noSymbols:
            return "No symbols are configured for refresh."
        case let .refreshFailed(message):
            return "Could not refresh market data: \(message)"
        }
    }
}

extension MarketDataRepository {
    func handleForegroundResume(at date: Date) async {
        _ = date
    }

    func handleBackgroundTransition(at date: Date) {
        _ = date
    }

    func manualRefresh() async {
        await start()
    }
}

enum MarketSeedingState: Equatable, Sendable {
    case idle
    case seeding
    case ready
    case failed(String)
    case fallbackMocked(String)
}
