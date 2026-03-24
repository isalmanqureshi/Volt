import Foundation

enum AnalyticsExportPreset: String, CaseIterable, Codable, Sendable {
    case orderHistoryOnly
    case realizedLedgerOnly
    case analyticsSummary
    case fullActivity

    var title: String {
        switch self {
        case .orderHistoryOnly: "Order History"
        case .realizedLedgerOnly: "Realized P&L"
        case .analyticsSummary: "Analytics Summary"
        case .fullActivity: "Full Activity"
        }
    }
}
