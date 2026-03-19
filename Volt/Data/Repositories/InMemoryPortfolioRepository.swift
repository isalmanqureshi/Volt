import Combine
import Foundation

final class InMemoryPortfolioRepository: PortfolioRepository {
    private let positionsSubject: CurrentValueSubject<[Position], Never>
    private let summarySubject: CurrentValueSubject<PortfolioSummary, Never>

    var positionsPublisher: AnyPublisher<[Position], Never> { positionsSubject.eraseToAnyPublisher() }
    var summaryPublisher: AnyPublisher<PortfolioSummary, Never> { summarySubject.eraseToAnyPublisher() }

    init() {
        let initialPositions: [Position] = []
        self.positionsSubject = CurrentValueSubject(initialPositions)
        self.summarySubject = CurrentValueSubject(
            PortfolioSummary(cashBalance: 10_000, positionsMarketValue: 0, unrealizedPnL: 0, totalEquity: 10_000, dayChange: 0)
        )
    }
}
