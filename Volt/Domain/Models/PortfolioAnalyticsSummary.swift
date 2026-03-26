import Foundation

struct PortfolioAnalyticsSummary: Equatable, Sendable {
    let totalRealizedPnL: Decimal
    let totalUnrealizedPnL: Decimal
    let averageWin: Decimal?
    let averageLoss: Decimal?
    let profitFactor: Decimal?
    let winRate: Decimal?
    let totalClosedTrades: Int
    let bestTrade: Decimal?
    let worstTrade: Decimal?
    let currentEquity: Decimal
    let startingBalance: Decimal?
    let netReturnPercent: Decimal?

    static let empty = PortfolioAnalyticsSummary(
        totalRealizedPnL: 0,
        totalUnrealizedPnL: 0,
        averageWin: nil,
        averageLoss: nil,
        profitFactor: nil,
        winRate: nil,
        totalClosedTrades: 0,
        bestTrade: nil,
        worstTrade: nil,
        currentEquity: 0,
        startingBalance: nil,
        netReturnPercent: nil
    )
}
