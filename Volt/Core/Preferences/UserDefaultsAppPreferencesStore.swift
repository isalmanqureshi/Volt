import Combine
import Foundation
internal import os

final class UserDefaultsAppPreferencesStore: AppPreferencesProviding {
    private struct PersistedEnvelope: Codable {
        var version: Int
        var preferences: AppPreferences
    }

    private struct LegacyPreferencesV1: Codable {
        var onboardingCompleted: Bool
        var aiSummariesEnabled: Bool
        var selectedEnvironment: TradingEnvironment
        var simulatorRisk: SimulatorRiskPreferences
        var activeRuntimeProfileID: String
    }
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
            let data = try JSONEncoder().encode(PersistedEnvelope(version: AppPreferences.schemaVersion, preferences: value))
            defaults.set(data, forKey: key)
        } catch {
            AppLogger.app.error("App preferences persistence failed")
        }
    }

    private static func load(defaults: UserDefaults, key: String) -> AppPreferences? {
        guard let data = defaults.data(forKey: key) else { return nil }
        do {
            if let envelope = try? JSONDecoder().decode(PersistedEnvelope.self, from: data) {
                let profile = RuntimeProfile.resolve(id: envelope.preferences.activeRuntimeProfileID)
                return AppPreferences(
                    onboardingCompleted: envelope.preferences.onboardingCompleted,
                    aiSummariesEnabled: envelope.preferences.aiSummariesEnabled,
                    selectedEnvironment: envelope.preferences.selectedEnvironment,
                    simulatorRisk: envelope.preferences.simulatorRisk.validated(),
                    activeRuntimeProfileID: profile.id,
                    activeDemoScenarioID: envelope.preferences.activeDemoScenarioID
                )
            }

            let legacy = try JSONDecoder().decode(LegacyPreferencesV1.self, from: data)
            AppLogger.migration.info("Migrated app preferences from legacy schema v1")
            let profile = RuntimeProfile.resolve(id: legacy.activeRuntimeProfileID)
            return AppPreferences(
                onboardingCompleted: legacy.onboardingCompleted,
                aiSummariesEnabled: legacy.aiSummariesEnabled,
                selectedEnvironment: legacy.selectedEnvironment,
                simulatorRisk: legacy.simulatorRisk.validated(),
                activeRuntimeProfileID: profile.id,
                activeDemoScenarioID: nil
            )
        } catch {
            AppLogger.app.error("App preferences decode failed. Falling back to defaults")
            defaults.removeObject(forKey: key)
            return nil
        }
    }
}
