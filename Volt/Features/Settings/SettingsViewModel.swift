import Combine
import Foundation
internal import os

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published private(set) var preferences: AppPreferences
    let runtimeProfiles = RuntimeProfile.all
    let scenarios: [DemoScenario]

    private let preferencesStore: AppPreferencesProviding
    private let scenarioBootstrap: DemoScenarioBootstrapping?

    init(preferencesStore: AppPreferencesProviding, scenarioBootstrap: DemoScenarioBootstrapping? = nil) {
        self.preferencesStore = preferencesStore
        self.scenarioBootstrap = scenarioBootstrap
        self.scenarios = scenarioBootstrap?.scenarios ?? []
        self.preferences = preferencesStore.currentPreferences

        preferencesStore.preferencesPublisher
            .receive(on: RunLoop.main)
            .assign(to: &$preferences)
    }

    func setAISummaries(_ enabled: Bool) {
        preferencesStore.update { $0.aiSummariesEnabled = enabled }
    }

    func setRuntimeProfile(_ id: String) {
        preferencesStore.selectRuntimeProfile(RuntimeProfile.resolve(id: id))
    }

    func setOrderSizeMode(_ mode: OrderSizeMode) {
        preferencesStore.update { $0.simulatorRisk.orderSizeMode = mode }
    }

    func setDefaultOrderSize(_ value: Decimal) {
        preferencesStore.update { $0.simulatorRisk.defaultOrderSizeValue = value }
    }

    func setRiskWarningsEnabled(_ enabled: Bool) {
        preferencesStore.update { $0.simulatorRisk.riskWarningsEnabled = enabled }
    }

    func setSlippage(_ preset: SlippagePreset) {
        preferencesStore.update { $0.simulatorRisk.slippagePreset = preset }
        AppLogger.app.debug("Simulator slippage preset changed to \(preset.rawValue, privacy: .public)")
    }

    func setVolatility(_ preset: SimulatorVolatilityPreset) {
        preferencesStore.update { $0.simulatorRisk.volatilityPreset = preset }
        AppLogger.app.debug("Simulator volatility preset changed to \(preset.rawValue, privacy: .public)")
    }

    func setTradeConfirmationMode(_ mode: TradeConfirmationMode) {
        preferencesStore.update { $0.simulatorRisk.tradeConfirmationMode = mode }
        AppLogger.app.debug("Trade confirmation mode changed to \(mode.rawValue, privacy: .public)")
    }

    func setWarningThresholdPercent(_ percent: Decimal) {
        preferencesStore.update { $0.simulatorRisk.warningThresholdPercent = percent }
    }

    func resetSimulatorControls() {
        preferencesStore.resetSimulatorControlsToProfileDefaults()
    }

    func resetOnboarding() {
        preferencesStore.resetOnboarding()
    }

    func setScenario(_ id: String) {
        guard id.isEmpty == false else {
            scenarioBootstrap?.resetScenario()
            return
        }
        scenarioBootstrap?.applyScenario(id: id)
    }
}
