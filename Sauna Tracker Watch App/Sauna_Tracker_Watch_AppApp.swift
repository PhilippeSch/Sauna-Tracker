//
//  Sauna_Tracker_Watch_AppApp.swift
//  Sauna Tracker Watch App
//

import SwiftUI

@main
struct Sauna_Tracker_Watch_AppApp: App {
    // The session store is owned here rather than inside the root view so it
    // exists, and is registered for App Intents, from the moment the app
    // launches: an Action button press launches the app and can run its
    // intent before any view has been built.
    @State private var store: SessionStore

    init() {
        let store = SessionStore(
            recorder: HealthKitSessionRecorder(),
            hapticScheduler: HapticScheduler()
        )
        store.makeCurrent()
        _store = State(initialValue: store)
    }

    var body: some Scene {
        WindowGroup {
            SessionRootView(store: store)
                .task {
                    await HealthKitAuthorization.requestAuthorization()
                    WatchConnectivityService.shared.activate()
                }
        }
    }
}
