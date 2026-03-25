import Combine
import Foundation
internal import os

final class UserDefaultsAppPreferencesStore: AppPreferencesProviding {
    private let defaults: UserDefaults
    private let key: String
    private let subject: CurrentValueSubject<AppPreferences, Never>

    var preferencesPublisher: AnyPublisher<AppPreferences, Never> { subject.eraseToAnyPublisher() }
    var currentPreferences: AppPreferences { subject.value }

    init(defaults: UserDefaults = .standard, key: String = "volt.app_preferences") {
        self.defaults = defaults
        self.key = key

        if let loaded = Self.load(defaults: defaults, key: key) {
            subject = CurrentValueSubject(loaded)
        } else {
            subject = CurrentValueSubject(.default)
        }
    }

    func update(_ mutate: (inout AppPreferences) -> Void) {
        var value = subject.value
        mutate(&value)
        value.simulatorRisk = value.simulatorRisk.validated()
        if RuntimeProfile.all.contains(where: { $0.id == value.activeRuntimeProfileID }) == false {
            value.activeRuntimeProfileID = RuntimeProfile.balanced.id
        }
        persist(value)
        subject.send(value)
    }

    func selectRuntimeProfile(_ profile: RuntimeProfile) {
        update {
            $0.activeRuntimeProfileID = profile.id
            $0.selectedEnvironment = profile.environment
            $0.simulatorRisk = profile.simulatorDefaults
        }
        AppLogger.app.info("Runtime profile switched to \(profile.id, privacy: .public)")
    }

    func resetSimulatorControlsToProfileDefaults() {
        let profile = currentPreferences.activeRuntimeProfile
        update { $0.simulatorRisk = profile.simulatorDefaults }
        AppLogger.app.info("Simulator controls reset for profile \(profile.id, privacy: .public)")
    }

    func resetOnboarding() {
        update { $0.onboardingCompleted = false }
        AppLogger.app.info("Onboarding reset from settings")
    }

    func completeOnboarding() {
        update { $0.onboardingCompleted = true }
        AppLogger.app.info("Onboarding completed")
    }

    private func persist(_ value: AppPreferences) {
        do {
            let data = try JSONEncoder().encode(value)
            defaults.set(data, forKey: key)
        } catch {
            AppLogger.app.error("App preferences persistence failed")
        }
    }

    private static func load(defaults: UserDefaults, key: String) -> AppPreferences? {
        guard let data = defaults.data(forKey: key) else { return nil }
        do {
            let decoded = try JSONDecoder().decode(AppPreferences.self, from: data)
            let profile = RuntimeProfile.resolve(id: decoded.activeRuntimeProfileID)
            return AppPreferences(
                onboardingCompleted: decoded.onboardingCompleted,
                aiSummariesEnabled: decoded.aiSummariesEnabled,
                selectedEnvironment: decoded.selectedEnvironment,
                simulatorRisk: decoded.simulatorRisk.validated(),
                activeRuntimeProfileID: profile.id
            )
        } catch {
            AppLogger.app.error("App preferences decode failed. Falling back to defaults")
            defaults.removeObject(forKey: key)
            return nil
        }
    }
}
