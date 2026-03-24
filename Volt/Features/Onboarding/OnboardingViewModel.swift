import Foundation

@MainActor
final class OnboardingViewModel: ObservableObject {
    @Published var step = 0
    @Published var enableAISummaries = true

    private let preferences: AppPreferencesProviding

    init(preferences: AppPreferencesProviding) {
        self.preferences = preferences
        self.enableAISummaries = preferences.currentPreferences.aiSummariesEnabled
    }

    var isLastStep: Bool { step >= 2 }

    func next() {
        step = min(step + 1, 2)
    }

    func complete() {
        preferences.update {
            $0.aiSummariesEnabled = enableAISummaries
            $0.onboardingCompleted = true
        }
    }

    func skip() {
        preferences.completeOnboarding()
    }
}
