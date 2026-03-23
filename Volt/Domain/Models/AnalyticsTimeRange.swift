import Foundation

enum AnalyticsTimeRange: String, CaseIterable, Codable, Sendable {
    case sevenDays
    case thirtyDays
    case ninetyDays
    case all

    var title: String {
        switch self {
        case .sevenDays: "7D"
        case .thirtyDays: "30D"
        case .ninetyDays: "90D"
        case .all: "All"
        }
    }

    func lowerBound(referenceDate: Date = Date(), calendar: Calendar = .current) -> Date? {
        switch self {
        case .sevenDays:
            calendar.date(byAdding: .day, value: -7, to: referenceDate)
        case .thirtyDays:
            calendar.date(byAdding: .day, value: -30, to: referenceDate)
        case .ninetyDays:
            calendar.date(byAdding: .day, value: -90, to: referenceDate)
        case .all:
            nil
        }
    }
}
