import Foundation

struct PortfolioInsightCard: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let body: String
}

struct TradeRecap: Equatable, Sendable {
    let title: String
    let body: String
}

protocol PortfolioSummaryInsightService {
    func makeInsights(summary: PortfolioSummary, positions: [Position], analytics: PortfolioAnalyticsSummary, recentActivity: [ActivityEvent]) -> [PortfolioInsightCard]
}

protocol TradeSummaryInsightService {
    func makeRecap(result: TradeExecutionResult, latestSummary: PortfolioSummary) -> TradeRecap
}
