import Foundation

struct TradeExecutionResult: Equatable, Sendable {
    let resultingPosition: Position?
    let orderRecord: OrderRecord
    let activityEvent: ActivityEvent
    let realizedPnLEntry: RealizedPnLEntry?
}
