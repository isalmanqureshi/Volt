import Foundation

struct RealizedDistributionBucket: Identifiable, Equatable, Sendable {
    enum Outcome: String, Sendable {
        case gain
        case loss
        case flat
    }

    let id: String
    let label: String
    let count: Int
    let totalPnL: Decimal
    let outcome: Outcome
}
