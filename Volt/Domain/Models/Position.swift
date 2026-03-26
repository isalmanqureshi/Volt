import Foundation

struct Position: Identifiable, Equatable, Codable, Sendable {
    let id: UUID
    let symbol: String
    let quantity: Decimal
    let averageEntryPrice: Decimal
    let currentPrice: Decimal
    let unrealizedPnL: Decimal
    let openedAt: Date
}
