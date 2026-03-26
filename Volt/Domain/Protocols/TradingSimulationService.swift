import Foundation

protocol TradingSimulationService {
    @discardableResult
    func placeOrder(_ draft: OrderDraft) throws -> TradeExecutionResult
}

enum TradingSimulationError: LocalizedError, Equatable {
    case invalidQuantity
    case invalidCloseQuantity
    case closeQuantityExceedsOpenQuantity(symbol: String)
    case missingPosition(symbol: String)
    case unsupportedAsset(symbol: String)
    case missingQuote(symbol: String)
    case insufficientFunds(required: Decimal, available: Decimal)
    case insufficientPositionQuantity(symbol: String)
    case repositoryUnavailable
    case persistenceSaveFailed
    case persistenceLoadFailed
    case executionFailed(reason: String)

    var errorDescription: String? {
        switch self {
        case .invalidQuantity:
            return "Enter a quantity greater than 0."
        case .invalidCloseQuantity:
            return "Enter a valid quantity to close."
        case let .closeQuantityExceedsOpenQuantity(symbol):
            return "Close quantity exceeds your open \(symbol) position."
        case let .missingPosition(symbol):
            return "No open \(symbol) position was found."
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
        case .persistenceSaveFailed:
            return "Could not save your portfolio changes locally."
        case .persistenceLoadFailed:
            return "Could not recover prior portfolio state."
        case let .executionFailed(reason):
            return "Order execution failed: \(reason)"
        }
    }
}
