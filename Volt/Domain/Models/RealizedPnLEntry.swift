import Foundation

struct RealizedPnLEntry: Identifiable, Equatable, Codable, Sendable {
    let id: UUID
    let symbol: String
    let quantityClosed: Decimal
    let averageEntryPrice: Decimal
    let exitPrice: Decimal
    let realizedPnL: Decimal
    let closedAt: Date
    let linkedPositionID: UUID
    let note: String?
}
