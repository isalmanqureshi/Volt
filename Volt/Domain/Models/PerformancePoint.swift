import Foundation

struct PerformancePoint: Identifiable, Equatable, Sendable {
    let id: UUID
    let timestamp: Date
    let equity: Decimal
    let cashBalance: Decimal
    let unrealizedPnL: Decimal
    let cumulativeRealizedPnL: Decimal

    init(id: UUID = UUID(), timestamp: Date, equity: Decimal, cashBalance: Decimal, unrealizedPnL: Decimal, cumulativeRealizedPnL: Decimal) {
        self.id = id
        self.timestamp = timestamp
        self.equity = equity
        self.cashBalance = cashBalance
        self.unrealizedPnL = unrealizedPnL
        self.cumulativeRealizedPnL = cumulativeRealizedPnL
    }
}
