import Foundation

struct Quote: Equatable, Sendable {
    let symbol: String
    let lastPrice: Decimal
    let changePercent: Decimal
    let timestamp: Date
    let source: String
    let isSimulated: Bool
}
