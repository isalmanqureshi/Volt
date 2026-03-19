import Foundation

struct MarketTick: Equatable, Sendable {
    let symbol: String
    let price: Decimal
    let timestamp: Date
    let isSimulated: Bool
}
