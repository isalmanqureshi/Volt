import Foundation

struct ExportableLedgerRow: Equatable, Sendable {
    let timestamp: Date
    let symbol: String
    let eventType: String
    let side: String
    let quantity: Decimal
    let price: Decimal
    let grossValue: Decimal
    let realizedPnL: Decimal?
}
