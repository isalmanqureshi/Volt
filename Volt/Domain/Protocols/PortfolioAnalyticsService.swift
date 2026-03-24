import Combine
import Foundation

protocol PortfolioAnalyticsService {
    var summaryPublisher: AnyPublisher<PortfolioAnalyticsSummary, Never> { get }
    var performancePublisher: AnyPublisher<[PerformancePoint], Never> { get }
    var dailyPerformancePublisher: AnyPublisher<[DailyPerformanceBucket], Never> { get }
    var realizedDistributionPublisher: AnyPublisher<[RealizedDistributionBucket], Never> { get }
    var filteredOrdersPublisher: AnyPublisher<[OrderRecord], Never> { get }
    var filteredActivityPublisher: AnyPublisher<[ActivityEvent], Never> { get }
    var availableSymbolsPublisher: AnyPublisher<[String], Never> { get }

    var currentSummary: PortfolioAnalyticsSummary { get }
    var currentPerformance: [PerformancePoint] { get }
    var currentDailyPerformance: [DailyPerformanceBucket] { get }
    var currentRealizedDistribution: [RealizedDistributionBucket] { get }
    var currentFilter: HistoryFilter { get }

    func updateFilter(_ filter: HistoryFilter)
    func positionHistory(symbol: String) -> PositionHistorySummary
}

enum AnalyticsComputationError: Error {
    case noHistory
    case invalidFilter
}
