import Combine
import Foundation

@MainActor
final class AnalyticsViewModel: ObservableObject {
    @Published var selectedRange: AnalyticsTimeRange = .thirtyDays {
        didSet {
            guard selectedRange != oldValue else { return }
            applyRangeFilter()
        }
    }
    @Published private(set) var summary: PortfolioAnalyticsSummary = .empty
    @Published private(set) var performancePoints: [PerformancePoint] = []

    private let analyticsService: PortfolioAnalyticsService
    private var cancellables = Set<AnyCancellable>()

    init(analyticsService: PortfolioAnalyticsService) {
        self.analyticsService = analyticsService

        analyticsService.summaryPublisher
            .receive(on: RunLoop.main)
            .assign(to: &$summary)

        analyticsService.performancePublisher
            .receive(on: RunLoop.main)
            .assign(to: &$performancePoints)

        selectedRange = analyticsService.currentFilter.timeRange
        applyRangeFilter()
    }

    private func applyRangeFilter() {
        var filter = analyticsService.currentFilter
        filter.timeRange = selectedRange
        analyticsService.updateFilter(filter)
    }
}
