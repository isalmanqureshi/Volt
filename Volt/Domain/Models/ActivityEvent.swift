import Foundation

struct ActivityEvent: Identifiable, Equatable, Codable, Sendable {
    enum Kind: String, Codable, Sendable {
        case buy
        case sell
        case partialClose
        case fullClose
    }

    let id: UUID
    let kind: Kind
    let symbol: String
    let quantity: Decimal
    let price: Decimal
    let timestamp: Date
    let orderID: UUID
    let relatedPositionID: UUID?
    let realizedPnL: Decimal?
}
