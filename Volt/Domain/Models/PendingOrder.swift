import Foundation

/// An order resting in the local book until the simulated price crosses its
/// trigger. Unlike market orders, pending orders are filled by the shared tick
/// stream itself — no user gesture is involved at fill time.
struct PendingOrder: Identifiable, Equatable, Sendable {
    enum Status: Equatable, Sendable {
        case pending
        /// The trigger crossed but the fill was refused (e.g. insufficient cash
        /// or position at fill time). Kept in the book so the UI can say why.
        case rejected(reason: String)
    }

    let id: UUID
    let symbol: String
    let side: OrderSide
    /// Only `.limit` and `.stop` rest in the book; `.market` fills immediately
    /// through `TradingSimulationService` and never becomes a `PendingOrder`.
    let type: OrderType
    let quantity: Decimal
    let triggerPrice: Decimal
    let createdAt: Date
    var status: Status

    /// Crossing rule per order shape:
    /// - limit buy fills at or below the trigger (buy the dip)
    /// - limit sell fills at or above the trigger (take profit)
    /// - stop buy fills at or above the trigger (breakout entry)
    /// - stop sell fills at or below the trigger (stop-loss)
    func shouldTrigger(atPrice price: Decimal) -> Bool {
        switch (type, side) {
        case (.limit, .buy): return price <= triggerPrice
        case (.limit, .sell): return price >= triggerPrice
        case (.stop, .buy): return price >= triggerPrice
        case (.stop, .sell): return price <= triggerPrice
        case (.market, _): return true
        }
    }
}
