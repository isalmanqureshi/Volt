import Foundation

struct OrderDraft: Equatable, Sendable {
    let assetSymbol: String
    let side: OrderSide
    let type: OrderType
    let quantity: Decimal
    let estimatedPrice: Decimal?
    let submittedAt: Date
    let limitPrice: Decimal?
    let stopPrice: Decimal?
}
