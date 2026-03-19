import Foundation

struct Candle: Equatable, Sendable {
    let symbol: String
    let interval: String
    let open: Decimal
    let high: Decimal
    let low: Decimal
    let close: Decimal
    let volume: Decimal
    let timestamp: Date
    let isComplete: Bool
}
