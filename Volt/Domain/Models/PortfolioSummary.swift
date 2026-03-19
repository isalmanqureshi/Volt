import Foundation

struct PortfolioSummary: Equatable, Sendable {
    let cashBalance: Decimal
    let positionsMarketValue: Decimal
    let unrealizedPnL: Decimal
    let totalEquity: Decimal
    let dayChange: Decimal
}
