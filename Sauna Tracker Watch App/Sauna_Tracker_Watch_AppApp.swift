//
//  Sauna_Tracker_Watch_AppApp.swift
//  Sauna Tracker Watch App
//

import SwiftUI

@main
struct Sauna_Tracker_Watch_AppApp: App {
    var body: some Scene {
        WindowGroup {
            SessionRootView()
                .task {
                    await HealthKitAuthorization.requestAuthorization()
                    WatchConnectivityService.shared.activate()
                }
        }
    }
}
