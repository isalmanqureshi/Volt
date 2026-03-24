import Foundation

struct LocalInsightSummaryService: PortfolioSummaryInsightService, TradeSummaryInsightService {
    func makeInsights(summary: PortfolioSummary, positions: [Position], analytics: PortfolioAnalyticsSummary, recentActivity: [ActivityEvent]) -> [PortfolioInsightCard] {
        var cards: [PortfolioInsightCard] = []

        cards.append(
            PortfolioInsightCard(
                id: "equity",
                title: "Portfolio recap",
                body: "Equity is \(summary.totalEquity.formatted(.currency(code: "USD"))). Realized P&L is \(summary.realizedPnL.formatted(.currency(code: "USD"))) and unrealized P&L is \(summary.unrealizedPnL.formatted(.currency(code: "USD")))."
            )
        )

        if let largest = positions.max(by: { ($0.currentPrice * $0.quantity) < ($1.currentPrice * $1.quantity) }) {
            cards.append(
                PortfolioInsightCard(
                    id: "largest",
                    title: "Largest exposure",
                    body: "\(largest.symbol) is your largest open position at \((largest.currentPrice * largest.quantity).formatted(.currency(code: "USD")))."
                )
            )
        }

        if let winRate = analytics.winRate {
            cards.append(
                PortfolioInsightCard(
                    id: "winrate",
                    title: "Trade pattern",
                    body: "Closed trades: \(analytics.totalClosedTrades). Win rate is \((winRate * 100).formatted(.number.precision(.fractionLength(1...2))))%."
                )
            )
        }

        if let latestEvent = recentActivity.first {
            cards.append(
                PortfolioInsightCard(
                    id: "activity",
                    title: "Recent activity",
                    body: "Latest event: \(latestEvent.kind.rawValue) \(latestEvent.quantity.formatted()) of \(latestEvent.symbol)."
                )
            )
        }

        return Array(cards.prefix(3))
    }

    func makeRecap(result: TradeExecutionResult, latestSummary: PortfolioSummary) -> TradeRecap {
        let order = result.orderRecord
        let remainingText: String
        if let position = result.resultingPosition {
            remainingText = "Remaining quantity: \(position.quantity.formatted())."
        } else {
            remainingText = "Position fully closed."
        }

        let realized = result.realizedPnLEntry?.realizedPnL
        let realizedText = realized.map { " Realized P&L: \($0.formatted(.currency(code: "USD")))." } ?? ""

        return TradeRecap(
            title: "Trade recap",
            body: "\(order.side == .buy ? "Bought" : "Sold") \(order.quantity.formatted()) of \(order.symbol) at \(order.executedPrice.formatted(.currency(code: "USD"))). \(remainingText) Equity now \(latestSummary.totalEquity.formatted(.currency(code: "USD"))).\(realizedText)"
        )
    }
}
