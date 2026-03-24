import Combine
import Foundation

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published private(set) var preferences: AppPreferences

    private let preferencesStore: AppPreferencesProviding
    private var cancellables = Set<AnyCancellable>()

    init(preferencesStore: AppPreferencesProviding) {
        self.preferencesStore = preferencesStore
        self.preferences = preferencesStore.currentPreferences

        preferencesStore.preferencesPublisher
            .receive(on: RunLoop.main)
            .assign(to: &$preferences)
    }

    func setAISummaries(_ enabled: Bool) {
        preferencesStore.update { $0.aiSummariesEnabled = enabled }
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

    func setLargeOrderConfirmation(_ enabled: Bool) {
        preferencesStore.update { $0.simulatorRisk.requiresLargeOrderConfirmation = enabled }
    }

    func resetOnboarding() {
        preferencesStore.resetOnboarding()
    }
}
