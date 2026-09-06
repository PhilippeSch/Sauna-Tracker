//
//  Sauna_CompanionUITestsLaunchTests.swift
//  Sauna CompanionUITests
//
//  Created by Philippe Scheuber on 17.08.2026.
//

import XCTest

final class Sauna_CompanionUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        // Same reason as in Sauna_CompanionUITests: without this the launch
        // screenshot on a fresh simulator is the Health permission sheet
        // rather than the app.
        app.launchEnvironment[Sauna_CompanionUITests.skipHealthPromptKey] = "1"
        app.launch()

        // Insert steps here to perform after app launch but before taking a screenshot,
        // such as logging into a test account or navigating somewhere in the app
        // XCUIAutomation Documentation
        // https://developer.apple.com/documentation/xcuiautomation

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
