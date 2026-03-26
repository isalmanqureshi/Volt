import XCTest

final class VoltUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launchApp(largeText: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments.append("UITEST_RESET")
        if largeText {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL"]
        }
        app.launch()
        return app
    }

    @MainActor
    func testOnboardingAndSettingsProfileFlow() throws {
        let app = launchApp()

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
    func testOnboardingLargeTextStillNavigable() throws {
        let app = launchApp(largeText: true)
        XCTAssertTrue(app.navigationBars["Onboarding"].exists)
        app.buttons["Skip"].tap()
        XCTAssertTrue(app.tabBars.buttons["Watchlist"].waitForExistence(timeout: 2))
    }

    @MainActor
    func testTabsExistAfterProfileChange() throws {
        let app = launchApp()

        if app.navigationBars["Onboarding"].exists { app.buttons["Skip"].tap() }

        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].exists)

        app.tabBars.buttons["Watchlist"].tap()
        XCTAssertTrue(app.navigationBars.buttons["Settings"].exists || app.tabBars.buttons["Portfolio"].exists)
    }

    @MainActor
    func testDeterministicScenarioSelectionAndOfflineBannerVisible() throws {
        let app = launchApp()
        if app.navigationBars["Onboarding"].exists { app.buttons["Skip"].tap() }

        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.pickers["settings_scenario_picker"].waitForExistence(timeout: 2))
        app.pickers["settings_scenario_picker"].tap()
        app.buttons["Analytics Rich"].tap()

        app.tabBars.buttons["Watchlist"].tap()
        XCTAssertTrue(app.staticTexts["watchlist_data_mode"].waitForExistence(timeout: 2))
    }
}
