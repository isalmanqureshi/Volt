import Combine
import Foundation

/// Placement request for an order that should rest until its trigger crosses.
struct PendingOrderRequest: Equatable, Sendable {
    let symbol: String
    let side: OrderSide
    let type: OrderType
    let quantity: Decimal
    let triggerPrice: Decimal
    let submittedAt: Date
}

protocol PendingOrderMatching {
    var pendingOrdersPublisher: AnyPublisher<[PendingOrder], Never> { get }
    var currentPendingOrders: [PendingOrder] { get }

    @discardableResult
    func place(_ request: PendingOrderRequest) throws -> PendingOrder
    func cancel(id: UUID)
}

enum PendingOrderError: LocalizedError, Equatable {
    case invalidQuantity
    case invalidTriggerPrice
    case unsupportedOrderType
    case unsupportedAsset(symbol: String)
    case missingPosition(symbol: String)
    case insufficientFunds(required: Decimal, available: Decimal)

    var errorDescription: String? {
        switch self {
        case .invalidQuantity:
            return "Enter a quantity greater than 0."
        case .invalidTriggerPrice:
            return "Enter a trigger price greater than 0."
        case .unsupportedOrderType:
            return "Only limit and stop orders can rest in the book."
        case let .unsupportedAsset(symbol):
            return "\(symbol) is not currently supported."
        case let .missingPosition(symbol):
            return "No open \(symbol) position covers this sell order."
        case let .insufficientFunds(required, available):
            return "Insufficient funds. Required \(required.formatted(.currency(code: "USD"))), available \(available.formatted(.currency(code: "USD")))."
        }
    }
}
