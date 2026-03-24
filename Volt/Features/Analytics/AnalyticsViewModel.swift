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

    private let analyticsService: PortfolioAnalyticsService
    private let onRangeChanged: ((AnalyticsTimeRange) -> Void)?
    private var cancellables = Set<AnyCancellable>()

    init(
        analyticsService: PortfolioAnalyticsService,
        initialRange: AnalyticsTimeRange? = nil,
        onRangeChanged: ((AnalyticsTimeRange) -> Void)? = nil
    ) {
        self.analyticsService = analyticsService
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
    }

    private func applyRangeFilter() {
        var filter = analyticsService.currentFilter
        filter.timeRange = selectedRange
        analyticsService.updateFilter(filter)
    }
}
