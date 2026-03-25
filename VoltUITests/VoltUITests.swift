import XCTest

final class VoltUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testOnboardingAndSettingsProfileFlow() throws {
        let app = XCUIApplication()
        app.launchArguments.append("UITEST_RESET")
        app.launch()

        XCTAssertTrue(app.navigationBars["Onboarding"].exists)
        app.buttons["Skip"].tap()

        XCTAssertTrue(app.tabBars.buttons["Watchlist"].waitForExistence(timeout: 2))
        app.tabBars.buttons["Settings"].tap()

        let profilePicker = app.pickers["Profile"]
        XCTAssertTrue(profilePicker.exists)

        app.buttons["Restart Onboarding"].tap()
        app.terminate()

        let relaunched = XCUIApplication()
        relaunched.launch()
        XCTAssertTrue(relaunched.navigationBars["Onboarding"].waitForExistence(timeout: 2))
    }

    @MainActor
    func testTabsExistAfterProfileChange() throws {
        let app = XCUIApplication()
        app.launchArguments.append("UITEST_RESET")
        app.launch()

        if app.navigationBars["Onboarding"].exists { app.buttons["Skip"].tap() }

        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].exists)

        app.tabBars.buttons["Watchlist"].tap()
        XCTAssertTrue(app.navigationBars.buttons["Settings"].exists || app.tabBars.buttons["Portfolio"].exists)
    }
}
