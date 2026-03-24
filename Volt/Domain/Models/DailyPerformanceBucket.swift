import Foundation

struct DailyPerformanceBucket: Identifiable, Equatable, Sendable {
    var id: Date { day }
    let day: Date
    let realizedPnL: Decimal
    let tradeCount: Int
}
