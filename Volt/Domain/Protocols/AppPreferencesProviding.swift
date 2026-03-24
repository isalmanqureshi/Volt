import Combine
import Foundation

protocol AppPreferencesProviding {
    var preferencesPublisher: AnyPublisher<AppPreferences, Never> { get }
    var currentPreferences: AppPreferences { get }
    func update(_ mutate: (inout AppPreferences) -> Void)
    func resetOnboarding()
    func completeOnboarding()
}
