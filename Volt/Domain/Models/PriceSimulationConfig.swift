import Foundation

struct PriceSimulationConfig: Equatable, Sendable {
    enum VolatilityProfile: String, Codable, Sendable {
        case low
        case medium
        case high
    }

    struct ClampRules: Equatable, Sendable {
        let minimumPrice: Decimal
        let maximumTickMoveAbsolute: Decimal?
    }

    let maxPercentMovePerTick: Decimal
    let tickIntervalSeconds: TimeInterval
    let volatilityProfile: VolatilityProfile
    let clampRules: ClampRules

    static let `default` = PriceSimulationConfig(
        maxPercentMovePerTick: 0.003,
        tickIntervalSeconds: 1,
        volatilityProfile: .medium,
        clampRules: .init(minimumPrice: 0.0000001, maximumTickMoveAbsolute: nil)
    )
}
