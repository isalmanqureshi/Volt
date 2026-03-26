import Combine
import Foundation

@MainActor
final class AnalyticsViewModel: ObservableObject {
    @Published var selectedRange: AnalyticsTimeRange = .thirtyDays {
        didSet {
            guard selectedRange != oldValue else { return }
            applyRangeFilter()
            onRangeChanged?(selectedRange)
        }
    }
    @Published private(set) var summary: PortfolioAnalyticsSummary = .empty
    @Published private(set) var performancePoints: [PerformancePoint] = []
    @Published private(set) var dailyBuckets: [DailyPerformanceBucket] = []
    @Published private(set) var realizedDistribution: [RealizedDistributionBucket] = []
    @Published private(set) var insightCards: [InsightCardModel] = []

    private let analyticsService: PortfolioAnalyticsService
    private let onRangeChanged: ((AnalyticsTimeRange) -> Void)?
    private let preferencesStore: AppPreferencesProviding
    private let insightService: AnalyticsInsightService
    private var cancellables = Set<AnyCancellable>()

    init(
        analyticsService: PortfolioAnalyticsService,
        preferencesStore: AppPreferencesProviding = UserDefaultsAppPreferencesStore(),
        insightService: AnalyticsInsightService = LocalInsightSummaryService(),
        initialRange: AnalyticsTimeRange? = nil,
        onRangeChanged: ((AnalyticsTimeRange) -> Void)? = nil
    ) {
        self.analyticsService = analyticsService
        self.preferencesStore = preferencesStore
        self.insightService = insightService
        self.onRangeChanged = onRangeChanged

        analyticsService.summaryPublisher
            .receive(on: RunLoop.main)
            .assign(to: &$summary)

        analyticsService.performancePublisher
            .receive(on: RunLoop.main)
            .assign(to: &$performancePoints)

        analyticsService.dailyPerformancePublisher
            .receive(on: RunLoop.main)
            .assign(to: &$dailyBuckets)

        analyticsService.realizedDistributionPublisher
            .receive(on: RunLoop.main)
            .assign(to: &$realizedDistribution)

        selectedRange = initialRange ?? analyticsService.currentFilter.timeRange
        applyRangeFilter()

        Publishers.CombineLatest(analyticsService.summaryPublisher, preferencesStore.preferencesPublisher)
            .map { [weak self] summary, prefs in
                guard let self else { return [] }
                let ctx = RuntimeProfileInsightContext(profileName: prefs.activeRuntimeProfile.name, environmentName: prefs.selectedEnvironment.displayName, slippage: prefs.simulatorRisk.slippagePreset, volatility: prefs.simulatorRisk.volatilityPreset)
                return self.insightService.makeInsights(summary: summary, context: ctx)
            }
            .receive(on: RunLoop.main)
            .assign(to: &$insightCards)
    }

    private func applyRangeFilter() {
        var filter = analyticsService.currentFilter
        filter.timeRange = selectedRange
        analyticsService.updateFilter(filter)
    }
}
