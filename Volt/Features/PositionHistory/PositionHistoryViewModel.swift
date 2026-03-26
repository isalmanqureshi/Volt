import Foundation
import Combine

@MainActor
final class PositionHistoryViewModel: ObservableObject {
    
    @Published private(set) var summary: PositionHistorySummary

    private let symbol: String
    private let analyticsService: PortfolioAnalyticsService

    init(symbol: String, analyticsService: PortfolioAnalyticsService) {
        self.symbol = symbol
        self.analyticsService = analyticsService
        self.summary = analyticsService.positionHistory(symbol: symbol)
    }

    func refresh() {
        summary = analyticsService.positionHistory(symbol: symbol)
    }
}
