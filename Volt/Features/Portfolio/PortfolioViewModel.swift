import Combine
import Foundation

@MainActor
final class PortfolioViewModel: ObservableObject {
    @Published private(set) var summary: PortfolioSummary = PortfolioSummary(cashBalance: 0, positionsMarketValue: 0, unrealizedPnL: 0, realizedPnL: 0, totalEquity: 0, dayChange: 0)
    @Published private(set) var positions: [Position] = []
    @Published private(set) var recentActivity: [ActivityEvent] = []
    @Published private(set) var analyticsSummary: PortfolioAnalyticsSummary = .empty

    private var cancellables = Set<AnyCancellable>()

    init(portfolioRepository: PortfolioRepository, analyticsService: PortfolioAnalyticsService) {
        portfolioRepository.summaryPublisher
            .receive(on: RunLoop.main)
            .assign(to: &$summary)

        portfolioRepository.positionsPublisher
            .receive(on: RunLoop.main)
            .assign(to: &$positions)

        portfolioRepository.activityTimelinePublisher
            .map { Array($0.prefix(5)) }
            .receive(on: RunLoop.main)
            .assign(to: &$recentActivity)

        analyticsService.summaryPublisher
            .receive(on: RunLoop.main)
            .assign(to: &$analyticsSummary)
    }
}
