import Foundation

/// User-visible runtime profile controlling environment + simulator defaults.
struct RuntimeProfile: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let subtitle: String
    let environment: TradingEnvironment
    let simulatorDefaults: SimulatorRiskPreferences

    static let conservative = RuntimeProfile(
        id: "conservative",
        name: "Conservative",
        subtitle: "Lower volatility and tighter risk checks.",
        environment: .mock,
        simulatorDefaults: .conservative
    )

    static let balanced = RuntimeProfile(
        id: "balanced",
        name: "Balanced",
        subtitle: "Default demo profile for most users.",
        environment: .twelveDataSeededSimulation,
        simulatorDefaults: .default
    )

    static let aggressive = RuntimeProfile(
        id: "aggressive",
        name: "Aggressive",
        subtitle: "Higher slippage/volatility and lighter confirmations.",
        environment: .twelveDataSeededSimulation,
        simulatorDefaults: .aggressive
    )

    static let all: [RuntimeProfile] = [conservative, balanced, aggressive]

    static func resolve(id: String) -> RuntimeProfile {
        all.first(where: { $0.id == id }) ?? .balanced
    }
}
