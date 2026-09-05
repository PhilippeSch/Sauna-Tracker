//
//  ActionButtonIntents.swift
//  Sauna Tracker Watch App
//
//  Action button support on Apple Watch Ultra. watchOS drives the button in
//  two stages:
//
//      press 1 (idle)      StartWorkoutIntent -> starts the session
//      press 2, 3, 4 …     the "next action"  -> switches sauna <-> rest
//
//  The next action is an ordinary AppIntent the app donates while a workout
//  session is running. Two rules the first attempt at this got wrong:
//
//  * The next action must be a plain AppIntent. PauseWorkoutIntent and
//    ResumeWorkoutIntent belong to the Action + side button chord, not to a
//    single press, so chaining those left every press after the first doing
//    nothing.
//  * Arming does not have to happen inside an intent's result. The recorder
//    donates the toggle when the workout session starts, so the button works
//    just as well for a session started with the on-screen button.
//
//  What the app cannot do is claim the button: it has to be pointed here
//  once, under Settings > Action Button > Action: Workout > App: Sauna
//  Tracker. ActionButtonInfoView says so on first launch.
//

import AppIntents
import Foundation
import WatchKit
import os

private let intentLog = Logger(subsystem: "Scheuber.Sauna-Tracker", category: "Intents")

/// Set when a button press starts a session before the UI has registered its
/// store, so the start can still be finished once the app is up.
enum PendingSessionStart {
    private static let key = "saunaTracker.pendingStart"

    static var isRequested: Bool {
        get { UserDefaults.standard.bool(forKey: key) }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}

enum ActionButton {
    /// Makes the phase toggle the thing the next press runs. Called whenever a
    /// workout session starts, whichever way it was started.
    static func armPhaseToggle() async {
        do {
            try await StartSaunaWorkoutIntent()
                .donate(result: .result(actionButtonIntent: TogglePhaseIntent()))
            intentLog.info("Action button armed with the phase toggle")
        } catch {
            intentLog.error("Could not arm the Action button: \(error.localizedDescription)")
        }
    }
}

/// The Action button's workout picker needs something to name; a sauna
/// session has exactly one style.
enum SaunaWorkoutStyle: String, AppEnum {
    case sauna

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Sauna Session")
    }

    static var caseDisplayRepresentations: [SaunaWorkoutStyle: DisplayRepresentation] {
        [.sauna: DisplayRepresentation(title: "Sauna Session")]
    }
}

/// First press: starts the session. This is also what puts the app in the
/// list under Settings > Action Button > Action: Workout.
struct StartSaunaWorkoutIntent: AppIntent, StartWorkoutIntent {
    static var title: LocalizedStringResource = "Start Sauna Session"
    static var description = IntentDescription("Starts a sauna session and its first round.")

    // openAppWhenRun is deliberately left alone: the system launches the app
    // before running a start intent, and Apple's guidance is not to change it.

    @Parameter(title: "Type")
    var workoutStyle: SaunaWorkoutStyle

    static var suggestedWorkouts: [StartSaunaWorkoutIntent] {
        [StartSaunaWorkoutIntent(style: .sauna)]
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "Sauna Session")
    }

    init() {
        self.workoutStyle = .sauna
    }

    init(style: SaunaWorkoutStyle) {
        self.workoutStyle = style
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        if let store = SessionStore.current {
            if store.isActive {
                // A session is already running, so this press is really a
                // phase switch that arrived before the toggle was armed.
                store.advancePhase()
                intentLog.info("Start intent on a running session: switched phase")
            } else {
                // The workout session has to be up within 30 seconds of this
                // method returning, and startSession() starts it.
                await store.startSession()
            }
        } else {
            // Launched by the button, and the store is somehow not registered
            // yet: leave a note for the UI to finish the start.
            PendingSessionStart.isRequested = true
            intentLog.info("Start intent queued until the app is up")
        }
        return .result()
    }
}

/// Every press after that: ends the current phase and begins the other one.
struct TogglePhaseIntent: AppIntent {
    static var title: LocalizedStringResource = "Switch Phase"
    static var description = IntentDescription("Ends the current sauna round or rest phase and starts the other one.")

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        if let store = SessionStore.current, store.isActive {
            let before = store.currentPhase
            store.advancePhase()
            // The press happens with the app in the background and often with
            // Water Lock on, so a tap is the only confirmation the phase
            // actually changed.
            WKInterfaceDevice.current().play(.success)
            intentLog.info("Phase toggle: \(before.rawValue) -> \(store.currentPhase.rawValue)")
        } else {
            intentLog.info("Phase toggle with no running session")
        }

        // Re-arm, so the chain survives every press rather than only the first.
        return .result(actionButtonIntent: TogglePhaseIntent())
    }
}
