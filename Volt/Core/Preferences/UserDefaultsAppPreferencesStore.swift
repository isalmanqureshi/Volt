import Combine
import Foundation
internal import os

enum AppPreferencesStoreError: Error {
    case encodeFailed
    case decodeFailed
}

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
        persist(value)
        subject.send(value)
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
            return AppPreferences(
                onboardingCompleted: decoded.onboardingCompleted,
                aiSummariesEnabled: decoded.aiSummariesEnabled,
                selectedEnvironment: decoded.selectedEnvironment,
                simulatorRisk: decoded.simulatorRisk.validated()
            )
        } catch {
            AppLogger.app.error("App preferences decode failed. Falling back to defaults")
            defaults.removeObject(forKey: key)
            return nil
        }
    }
}
