import Foundation

struct HistoryFilter: Equatable, Codable, Sendable {
    var timeRange: AnalyticsTimeRange
    var symbol: String?
    var eventKinds: Set<ActivityEvent.Kind>

    static let `default` = HistoryFilter(timeRange: .all, symbol: nil, eventKinds: [])

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
}
