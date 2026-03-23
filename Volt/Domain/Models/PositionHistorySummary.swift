import Foundation

struct PositionHistorySummary: Equatable, Sendable {
    let symbol: String
    let totalBoughtQuantity: Decimal
    let totalSoldQuantity: Decimal
    let averageEntryPrice: Decimal?
    let averageExitPrice: Decimal?
    let realizedPnL: Decimal
    let orders: [OrderRecord]
    let activities: [ActivityEvent]

    static func empty(symbol: String) -> PositionHistorySummary {
        PositionHistorySummary(
            symbol: symbol,
            totalBoughtQuantity: 0,
            totalSoldQuantity: 0,
            averageEntryPrice: nil,
            averageExitPrice: nil,
            realizedPnL: 0,
            orders: [],
            activities: []
        )
    }
}
