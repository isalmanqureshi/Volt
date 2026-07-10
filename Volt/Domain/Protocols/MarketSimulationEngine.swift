import Combine
import Foundation

protocol MarketSimulationEngine {
    var ticksPublisher: AnyPublisher<MarketTick, Never> { get }
    /// Emits one element per tick cycle containing every symbol's tick, so
    /// consumers can apply a whole burst in a single pass (and publish one
    /// downstream update) instead of once per symbol.
    var tickBatchesPublisher: AnyPublisher<[MarketTick], Never> { get }
    var connectionStatePublisher: AnyPublisher<StreamConnectionState, Never> { get }

    func start(with seedQuotes: [Quote])
    func stop()
    func reseed(with quotes: [Quote])
}

extension MarketSimulationEngine {
    /// Engines that only emit per-symbol ticks are adapted to single-tick batches.
    var tickBatchesPublisher: AnyPublisher<[MarketTick], Never> {
        ticksPublisher.map { [$0] }.eraseToAnyPublisher()
    }
}
