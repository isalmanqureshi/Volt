import Foundation

final class DefaultTradingSimulationService: TradingSimulationService {
    enum TradingError: Error {
        case unsupportedInMilestone
    }

    func placeOrder(_ draft: OrderDraft) throws {
        AppLogger.portfolio.info("Received draft order for \(draft.assetSymbol, privacy: .public)")
        throw TradingError.unsupportedInMilestone
    }

    func handleTick(_ tick: MarketTick) {
        AppLogger.portfolio.debug("Tick received for portfolio simulation: \(tick.symbol, privacy: .public)")
    }
}
