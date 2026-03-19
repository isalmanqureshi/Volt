import Foundation

protocol TradingSimulationService {
    func placeOrder(_ draft: OrderDraft) throws
    func handleTick(_ tick: MarketTick)
}
