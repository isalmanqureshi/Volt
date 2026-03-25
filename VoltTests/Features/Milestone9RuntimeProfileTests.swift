import XCTest
@testable import Volt

final class Milestone9RuntimeProfileTests: XCTestCase {
    func testRuntimeProfilePersistenceRoundTrip() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let store = UserDefaultsAppPreferencesStore(defaults: defaults, key: "prefs")

        store.selectRuntimeProfile(.aggressive)

        let restored = UserDefaultsAppPreferencesStore(defaults: defaults, key: "prefs")
        XCTAssertEqual(restored.currentPreferences.activeRuntimeProfileID, RuntimeProfile.aggressive.id)
        XCTAssertEqual(restored.currentPreferences.selectedEnvironment, .twelveDataSeededSimulation)
    }

    func testLocalInsightsIncludeRuntimeContext() {
        let service = LocalInsightSummaryService()
        let cards = service.makeInsights(
            summary: .empty,
            context: RuntimeProfileInsightContext(profileName: "Aggressive", environmentName: "Mock", slippage: .high, volatility: .aggressive)
        )
        XCTAssertTrue(cards.first?.body.contains("Aggressive") == true)
        XCTAssertTrue(cards.first?.body.contains("slippage") == true)
    }

    func testSlippagePresetBasisPointsDeterministic() {
        XCTAssertEqual(SlippagePreset.off.basisPoints, 0)
        XCTAssertEqual(SlippagePreset.low.basisPoints, 5)
        XCTAssertEqual(SlippagePreset.medium.basisPoints, 12)
        XCTAssertEqual(SlippagePreset.high.basisPoints, 25)
    }
}
