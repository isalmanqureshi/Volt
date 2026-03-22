import Foundation

struct OrderRecord: Identifiable, Equatable, Codable, Sendable {
    enum Status: String, Codable, Sendable {
        case filled
    }

    enum Source: String, Codable, Sendable {
        case simulated
    }

    let id: UUID
    let symbol: String
    let side: OrderSide
    let type: OrderType
    let quantity: Decimal
    let executedPrice: Decimal
    let grossValue: Decimal
    let submittedAt: Date
    let executedAt: Date
    let status: Status
    let source: Source
    let linkedPositionID: UUID?
}
