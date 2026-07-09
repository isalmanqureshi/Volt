import Foundation

struct HistoryFilter: Equatable, Codable, Sendable {
    var timeRange: AnalyticsTimeRange
    var symbol: String?
    var eventKinds: Set<ActivityEvent.Kind>
    /// Buy/Sell restriction from the History screen's side pills. `nil` means "All".
    /// Optional so previously persisted/decoded filters (which lacked this key) still decode.
    var side: OrderSide?

    static let `default` = HistoryFilter(timeRange: .all, symbol: nil, eventKinds: [], side: nil)

    func contains(date: Date, referenceDate: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard let lowerBound = timeRange.lowerBound(referenceDate: referenceDate, calendar: calendar) else {
            return true
        }
        return date >= lowerBound
    }

    func allowsSymbol(_ candidate: String) -> Bool {
        guard let symbol else { return true }
        return symbol == candidate
    }

    func allows(kind: ActivityEvent.Kind) -> Bool {
        eventKinds.isEmpty || eventKinds.contains(kind)
    }

    /// Order-side gate. `nil` side allows everything.
    func allowsSide(_ candidate: OrderSide) -> Bool {
        guard let side else { return true }
        return side == candidate
    }

    /// Activity-event side gate, mapping event kinds to a buy/sell side
    /// (opens are buys; sells and closes are sell-side) so exports stay consistent
    /// with the orders list.
    func allowsSide(ofKind kind: ActivityEvent.Kind) -> Bool {
        guard let side else { return true }
        let kindSide: OrderSide = kind == .buy ? .buy : .sell
        return side == kindSide
    }
}
