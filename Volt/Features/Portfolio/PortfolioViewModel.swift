import Combine
import Foundation

@MainActor
final class PortfolioViewModel: ObservableObject {
    @Published private(set) var summary: PortfolioSummary = PortfolioSummary(cashBalance: 0, positionsMarketValue: 0, unrealizedPnL: 0, realizedPnL: 0, totalEquity: 0, dayChange: 0)
    @Published private(set) var positions: [Position] = []
    @Published private(set) var recentActivity: [ActivityEvent] = []
    @Published private(set) var analyticsSummary: PortfolioAnalyticsSummary = .empty
    @Published private(set) var insightCards: [PortfolioInsightCard] = []
    @Published private(set) var aiSummariesEnabled = true

    private let insightService: PortfolioSummaryInsightService
    private let preferencesStore: AppPreferencesProviding
    private var cancellables = Set<AnyCancellable>()

    init(
        portfolioRepository: PortfolioRepository,
        analyticsService: PortfolioAnalyticsService,
        preferencesStore: AppPreferencesProviding = UserDefaultsAppPreferencesStore(),
        insightService: PortfolioSummaryInsightService = LocalInsightSummaryService()
    ) {
        self.preferencesStore = preferencesStore
        self.insightService = insightService

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

        preferencesStore.preferencesPublisher
            .map(\.aiSummariesEnabled)
            .receive(on: RunLoop.main)
            .assign(to: &$aiSummariesEnabled)

        Publishers.CombineLatest4(
            portfolioRepository.summaryPublisher,
            portfolioRepository.positionsPublisher,
            analyticsService.summaryPublisher,
            portfolioRepository.activityTimelinePublisher.map { Array($0.prefix(5)) }
        )
        .map { [weak self] summary, positions, analytics, activity -> [PortfolioInsightCard] in
            guard let self else { return [] }
            guard self.preferencesStore.currentPreferences.aiSummariesEnabled else { return [] }
            return self.insightService.makeInsights(summary: summary, positions: positions, analytics: analytics, recentActivity: activity)
        }
        .receive(on: RunLoop.main)
        .assign(to: &$insightCards)
    }
}
