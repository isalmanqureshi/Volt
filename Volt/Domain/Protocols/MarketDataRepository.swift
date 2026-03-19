import Combine
import Foundation

protocol MarketDataRepository {
    var quotesPublisher: AnyPublisher<[Quote], Never> { get }
    var tickPublisher: AnyPublisher<MarketTick, Never> { get }
    var connectionStatePublisher: AnyPublisher<StreamConnectionState, Never> { get }

    func start() async
    func quote(for symbol: String) -> Quote?
    func watchlistQuotes(for symbols: [String]) -> AnyPublisher<[Quote], Never>
}
