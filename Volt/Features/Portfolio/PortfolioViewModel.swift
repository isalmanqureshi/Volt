import Combine
import Foundation

@MainActor
final class PortfolioViewModel: ObservableObject {
    @Published private(set) var summary: PortfolioSummary = PortfolioSummary(cashBalance: 0, positionsMarketValue: 0, unrealizedPnL: 0, totalEquity: 0, dayChange: 0)
    @Published private(set) var positions: [Position] = []

    private var cancellables = Set<AnyCancellable>()

    init(portfolioRepository: PortfolioRepository) {
        portfolioRepository.summaryPublisher
            .receive(on: RunLoop.main)
            .assign(to: &$summary)

        portfolioRepository.positionsPublisher
            .receive(on: RunLoop.main)
            .assign(to: &$positions)
    }
}
