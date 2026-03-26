import Foundation
import Combine
internal import os

@MainActor
final class OnboardingViewModel: ObservableObject {
    @Published var step = 0
    @Published var enableAISummaries = true
    @Published var starterProfileID: String = RuntimeProfile.balanced.id

    private let preferences: AppPreferencesProviding

    init(preferences: AppPreferencesProviding) {
        self.preferences = preferences
        self.enableAISummaries = preferences.currentPreferences.aiSummariesEnabled
        self.starterProfileID = preferences.currentPreferences.activeRuntimeProfileID
    }

    var isLastStep: Bool { step >= 2 }

    func next() {
        step = min(step + 1, 2)
    }

    func complete() {
        let profile = RuntimeProfile.resolve(id: starterProfileID)
        preferences.selectRuntimeProfile(profile)
        preferences.update {
            $0.aiSummariesEnabled = enableAISummaries
            $0.onboardingCompleted = true
        }
        AppLogger.app.info("Onboarding starter profile selected \(profile.id, privacy: .public)")
    }

    func skip() {
        preferences.completeOnboarding()
    }
}
