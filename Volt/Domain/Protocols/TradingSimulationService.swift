import Foundation

protocol TradingSimulationService {
    @discardableResult
    func placeOrder(_ draft: OrderDraft) throws -> Position
}

enum TradingSimulationError: LocalizedError, Equatable {
    case invalidQuantity
    case unsupportedAsset(symbol: String)
    case missingQuote(symbol: String)
    case insufficientFunds(required: Decimal, available: Decimal)
    case insufficientPositionQuantity(symbol: String)
    case repositoryUnavailable
    case executionFailed(reason: String)

    var errorDescription: String? {
        switch self {
        case .invalidQuantity:
            return "Enter a quantity greater than 0."
        case let .unsupportedAsset(symbol):
            return "\(symbol) is not currently supported."
        case let .missingQuote(symbol):
            return "A live quote for \(symbol) is unavailable. Try again shortly."
        case let .insufficientFunds(required, available):
            return "Insufficient funds. Required \(required.formatted(.currency(code: "USD"))), available \(available.formatted(.currency(code: "USD")))."
        case let .insufficientPositionQuantity(symbol):
            return "Not enough \(symbol) quantity to sell."
        case .repositoryUnavailable:
            return "Trading is temporarily unavailable."
        case let .executionFailed(reason):
            return "Order execution failed: \(reason)"
        }
    }
}
