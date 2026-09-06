//
//  Sauna_CompanionUITests.swift
//  Sauna CompanionUITests
//
//  A smoke test over the three tabs. It needs no Health data and grants no
//  permissions, so it runs the same on a clean simulator and on CI: what it
//  proves is that each tab builds and presents without crashing, which is
//  exactly the regression a change to any one screen tends to cause.
//

import XCTest

final class Sauna_CompanionUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Must match `Sauna_CompanionApp.skipHealthPromptKey`.
    static let skipHealthPromptKey = "SAUNA_UITEST_SKIP_HEALTH_PROMPT"

    /// English is forced so the assertions below can match on text without
    /// depending on the simulator's language — the app ships in four.
    ///
    /// The Health permission prompt is switched off: it is a system sheet
    /// covering the app, and a simulator that has not been asked before — a
    /// fresh CI runner, every run — would fail every assertion underneath it.
    @MainActor
    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launchEnvironment[Self.skipHealthPromptKey] = "1"
        app.launch()
        return app
    }

    @MainActor
    func testEachTabOpens() throws {
        let app = launchApp()

        // Statistics is the tab the app opens on.
        XCTAssertTrue(
            app.navigationBars["Statistics"].waitForExistence(timeout: 10),
            "the app should open on the Statistics tab"
        )

        for tab in ["History", "Settings"] {
            let button = app.tabBars.buttons[tab]
            XCTAssertTrue(button.waitForExistence(timeout: 5), "missing tab: \(tab)")
            button.tap()
            XCTAssertTrue(
                app.navigationBars[tab].waitForExistence(timeout: 5),
                "tapping \(tab) should show the \(tab) screen"
            )
        }
    }

    @MainActor
    func testSettingsShowsItsControls() throws {
        let app = launchApp()

        let settings = app.tabBars.buttons["Settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 10))
        settings.tap()

        // The three things settings is for. The weight field itself only
        // appears once the override is switched on, so only its toggle is
        // asserted here.
        XCTAssertTrue(app.staticTexts["Calorie Estimate"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.switches["Vibration"].exists, "missing the vibration toggle")
        XCTAssertTrue(app.switches["Override HealthKit Weight"].exists, "missing the weight override toggle")
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
