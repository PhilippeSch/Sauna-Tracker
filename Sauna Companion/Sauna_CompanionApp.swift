//
//  Sauna_CompanionApp.swift
//  Sauna Companion
//

import SwiftUI

@main
struct Sauna_CompanionApp: App {
    /// UI tests set this in the launch environment. The HealthKit permission
    /// sheet is a system view that covers the whole app, so on a simulator
    /// that has never been asked — a fresh CI runner, every time — it makes
    /// every on-screen assertion fail. The UI tests check navigation, not
    /// Health, so they opt out of the prompt.
    ///
    /// Kept in sync with `Sauna_CompanionUITests.skipHealthPromptKey`.
    static let skipHealthPromptKey = "SAUNA_UITEST_SKIP_HEALTH_PROMPT"

    private var shouldRequestHealthAuthorization: Bool {
        ProcessInfo.processInfo.environment[Self.skipHealthPromptKey] != "1"
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .task {
                    if shouldRequestHealthAuthorization {
                        await HealthKitAuthorization.requestAuthorization()
                    }
                    WatchConnectivityService.shared.activate()
                }
        }
    }
}
