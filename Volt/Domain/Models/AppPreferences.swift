import Foundation

struct AppPreferences: Codable, Equatable, Sendable {
    static let schemaVersion = 2

    var onboardingCompleted: Bool
    var aiSummariesEnabled: Bool
    var selectedEnvironment: TradingEnvironment
    var simulatorRisk: SimulatorRiskPreferences
    var activeRuntimeProfileID: String
    var activeDemoScenarioID: String?

    var activeRuntimeProfile: RuntimeProfile {
        RuntimeProfile.resolve(id: activeRuntimeProfileID)
    }

    static let `default` = AppPreferences(
        onboardingCompleted: false,
        aiSummariesEnabled: true,
        selectedEnvironment: RuntimeProfile.balanced.environment,
        simulatorRisk: RuntimeProfile.balanced.simulatorDefaults,
        activeRuntimeProfileID: RuntimeProfile.balanced.id,
        activeDemoScenarioID: nil
    )
}
