import Foundation

struct PortfolioInsightCard: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let body: String
}

struct InsightCardModel: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let body: String
}

struct InsightSectionModel: Equatable, Sendable {
    let title: String
    let cards: [InsightCardModel]
}

struct RuntimeProfileInsightContext: Equatable, Sendable {
    let profileName: String
    let environmentName: String
    let slippage: SlippagePreset
    let volatility: SimulatorVolatilityPreset
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

protocol AnalyticsInsightService {
    func makeInsights(summary: PortfolioAnalyticsSummary, context: RuntimeProfileInsightContext) -> [InsightCardModel]
}

protocol HistoryInsightService {
    func makeInsights(orders: [OrderRecord], activity: [ActivityEvent], context: RuntimeProfileInsightContext) -> [InsightCardModel]
}
