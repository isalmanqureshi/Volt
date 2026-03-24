import Foundation

struct AppPreferences: Codable, Equatable, Sendable {
    var onboardingCompleted: Bool
    var aiSummariesEnabled: Bool
    var selectedEnvironment: TradingEnvironment
    var simulatorRisk: SimulatorRiskPreferences

    static let `default` = AppPreferences(
        onboardingCompleted: false,
        aiSummariesEnabled: true,
        selectedEnvironment: .mock,
        simulatorRisk: .default
    )
}
