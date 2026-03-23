import Foundation

struct PersistedPortfolioState: Equatable, Codable, Sendable {
    let cashBalance: Decimal
    let openPositions: [Position]
    let orderHistory: [OrderRecord]
    let realizedPnLHistory: [RealizedPnLEntry]
    let activityTimeline: [ActivityEvent]
    let savedAt: Date
}
