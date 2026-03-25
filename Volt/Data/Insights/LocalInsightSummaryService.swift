import Foundation

struct LocalInsightSummaryService: PortfolioSummaryInsightService, TradeSummaryInsightService, AnalyticsInsightService, HistoryInsightService {
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
            let totalMarketValue = positions.reduce(Decimal.zero) { $0 + ($1.currentPrice * $1.quantity) }
            let concentration = totalMarketValue > 0 ? ((largest.currentPrice * largest.quantity) / totalMarketValue) * 100 : 0
            cards.append(
                PortfolioInsightCard(
                    id: "largest",
                    title: "Largest exposure",
                    body: "\(largest.symbol) is \((largest.currentPrice * largest.quantity).formatted(.currency(code: "USD"))) (~\(concentration.formatted(.number.precision(.fractionLength(0...1))))% of open exposure)."
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

        if analytics.totalClosedTrades >= 3 {
            let realizedShare = summary.realizedPnL == 0 && summary.unrealizedPnL == 0
                ? Decimal.zero
                : (abs(summary.realizedPnL) / (abs(summary.realizedPnL) + abs(summary.unrealizedPnL))) * 100
            cards.append(
                PortfolioInsightCard(
                    id: "pnl-attribution",
                    title: "P&L attribution",
                    body: "About \(realizedShare.formatted(.number.precision(.fractionLength(0...1))))% of current P&L comes from realized history versus open positions."
                )
            )
        }

        return Array(cards.prefix(3))
    }

    func makeInsights(summary: PortfolioAnalyticsSummary, context: RuntimeProfileInsightContext) -> [InsightCardModel] {
        var cards = [
            InsightCardModel(
                id: "runtime",
                title: "Runtime context",
                body: "\(context.profileName) profile on \(context.environmentName). Volatility: \(context.volatility.title), slippage: \(context.slippage.title)."
            )
        ]
        let realized = summary.totalRealizedPnL
        let unrealized = summary.totalUnrealizedPnL
        cards.append(
            InsightCardModel(
                id: "contribution",
                title: "P&L contribution",
                body: "Realized contribution is \(realized.formatted(.currency(code: "USD"))) and unrealized contribution is \(unrealized.formatted(.currency(code: "USD")))."
            )
        )

        if let winRate = summary.winRate {
            cards.append(
                InsightCardModel(
                    id: "quality",
                    title: "Execution quality",
                    body: "Closed trades: \(summary.totalClosedTrades). Win rate: \((winRate * 100).formatted(.number.precision(.fractionLength(0...1))))%. Interpret with profile slippage \(context.slippage.title)."
                )
            )
        }
        return cards
    }

    func makeInsights(orders: [OrderRecord], activity: [ActivityEvent], context: RuntimeProfileInsightContext) -> [InsightCardModel] {
        guard orders.isEmpty == false || activity.isEmpty == false else {
            return [InsightCardModel(id: "empty", title: "History context", body: "No activity yet for \(context.profileName) profile.")]
        }
        let symbols = Set(orders.map(\.symbol))
        return [
            InsightCardModel(
                id: "activity",
                title: "Activity breadth",
                body: "You traded \(symbols.count) symbol(s). Current simulation volatility is \(context.volatility.title)."
            )
        ]
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
