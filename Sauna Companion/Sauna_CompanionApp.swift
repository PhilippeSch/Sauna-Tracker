//
//  Sauna_CompanionApp.swift
//  Sauna Companion
//

import SwiftUI

@main
struct Sauna_CompanionApp: App {
    var body: some Scene {
        WindowGroup {
            RootTabView()
                .task {
                    await HealthKitAuthorization.requestAuthorization()
                    WatchConnectivityService.shared.activate()
                }
        }
    }
}
