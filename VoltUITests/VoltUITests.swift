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

    private func openSettings(_ app: XCUIApplication) {
        // Settings is a sheet opened from the gear in the Watchlist header.
        app.buttons["Watchlist"].tap()
        app.buttons["Settings"].firstMatch.tap()
    }

    @MainActor
    func testOnboardingAndSettingsProfileFlow() throws {
        let app = launchApp()

        XCTAssertTrue(app.navigationBars["Onboarding"].exists)
        app.buttons["Skip"].tap()

        XCTAssertTrue(app.buttons["Watchlist"].waitForExistence(timeout: 2))
        openSettings(app)

        XCTAssertTrue(app.staticTexts["RUNTIME PROFILE"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Balanced"].exists)

        app.buttons["Restart onboarding"].tap()
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
        XCTAssertTrue(app.buttons["Watchlist"].waitForExistence(timeout: 2))
    }

    @MainActor
    func testAllFiveTabsExist() throws {
        let app = launchApp()

        if app.navigationBars["Onboarding"].exists { app.buttons["Skip"].tap() }

        for tab in ["Watchlist", "Chart", "Portfolio", "Trade", "Analytics"] {
            XCTAssertTrue(app.buttons[tab].waitForExistence(timeout: 2), "Missing tab: \(tab)")
        }

        app.buttons["Portfolio"].tap()
        XCTAssertTrue(app.staticTexts["Total Value"].waitForExistence(timeout: 2))

        app.buttons["Analytics"].tap()
        XCTAssertTrue(app.staticTexts["Win Rate"].waitForExistence(timeout: 2))
    }

    @MainActor
    func testDeterministicScenarioSelection() throws {
        let app = launchApp()
        if app.navigationBars["Onboarding"].exists { app.buttons["Skip"].tap() }

        openSettings(app)
        XCTAssertTrue(app.buttons["settings_scenario_picker"].waitForExistence(timeout: 2))
        app.buttons["settings_scenario_picker"].tap()
        app.buttons["Analytics Rich"].tap()

        XCTAssertTrue(app.staticTexts["SIMULATION"].waitForExistence(timeout: 2))
    }
}
