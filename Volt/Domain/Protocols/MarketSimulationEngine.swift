import Combine
import Foundation

protocol MarketSimulationEngine {
    var ticksPublisher: AnyPublisher<MarketTick, Never> { get }
    var connectionStatePublisher: AnyPublisher<StreamConnectionState, Never> { get }

    func start(with seedQuotes: [Quote])
    func stop()
    func reseed(with quotes: [Quote])
}
