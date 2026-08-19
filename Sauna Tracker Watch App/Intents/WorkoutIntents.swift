//
//  WorkoutIntents.swift
//  Sauna Tracker Watch App
//
//  Action button support on Apple Watch Ultra.
//
//  The button is not something an app polls or claims. watchOS drives it as a
//  *chain*: whatever an intent returns from `perform()` via
//  `.result(actionButtonIntent:)` becomes the thing the next press runs. The
//  chain is bootstrapped by StartWorkoutIntent, so it only exists once the
//  session was started by the button:
//
//      press 1  StartSaunaWorkoutIntent   -> starts the session,
//                                            arms Pause
//      press 2  PauseSaunaWorkoutIntent   -> switches to Rest, arms Resume
//      press 3  ResumeSaunaWorkoutIntent  -> starts the next round, arms Pause
//      ...
//
//  Consequence worth knowing: starting a session with the on-screen button
//  leaves the Action button unarmed, because nothing ever returned an
//  `actionButtonIntent`. That is the mechanism, not a bug in the app — see the
//  Action button section of the README.
//
//  Every perform() therefore returns `.result(actionButtonIntent:)` rather
//  than `.result()`, or the chain would end after one press.
//

import AppIntents
import Foundation
import os

private let intentLog = Logger(subsystem: "Scheuber.Sauna-Tracker", category: "Intents")

/// Set when a start arrives before the UI has registered its store, so the
/// session can still begin once the app finishes launching.
enum PendingSessionStart {
    private static let key = "saunaTracker.pendingStart"

    static var isRequested: Bool {
        get { UserDefaults.standard.bool(forKey: key) }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}

/// Advances the phase of the running session, if there is one.
@MainActor
private func advanceRunningSession(from intent: String) {
    guard let store = SessionStore.current else {
        intentLog.error("\(intent): no live session store registered")
        IntentDiagnostics.record(intent, "no store")
        return
    }
    guard store.isActive else {
        intentLog.info("\(intent): store found but no session is running")
        IntentDiagnostics.record(intent, "store idle")
        return
    }
    let before = store.currentPhase.rawValue
    store.advancePhase()
    let outcome = "\(before) -> \(store.currentPhase.rawValue)"
    intentLog.info("\(intent): phase \(outcome)")
    IntentDiagnostics.record(intent, outcome)
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

struct StartSaunaWorkoutIntent: AppIntent, StartWorkoutIntent {
    static var title: LocalizedStringResource = "Start Sauna Session"
    static var description = IntentDescription("Starts a sauna session and its first round.")

    /// Brings the app up, so the session it just started is on screen.
    static var openAppWhenRun: Bool { true }

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
        IntentDiagnostics.record("start", "invoked")

        if let store = SessionStore.current {
            if store.isActive {
                advanceRunningSession(from: "start(already running)")
            } else {
                await store.startSession()
                IntentDiagnostics.record("start", "session started")
            }
        } else {
            // Launched by the button: the UI has not come up to register a
            // store yet, so leave a note for it to start on appearance.
            PendingSessionStart.isRequested = true
            IntentDiagnostics.record("start", "queued until app is up")
        }

        // Arms the next press regardless — the chain must not depend on
        // whether the store happened to exist yet.
        return .result(actionButtonIntent: PauseSaunaWorkoutIntent())
    }
}

struct PauseSaunaWorkoutIntent: AppIntent, PauseWorkoutIntent {
    static var title: LocalizedStringResource = "Start Rest Phase"
    static var description = IntentDescription("Ends the current sauna round and starts the rest phase.")
    static var openAppWhenRun: Bool { false }

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        IntentDiagnostics.record("pause", "invoked")
        advanceRunningSession(from: "pause")
        return .result(actionButtonIntent: ResumeSaunaWorkoutIntent())
    }
}

struct ResumeSaunaWorkoutIntent: AppIntent, ResumeWorkoutIntent {
    static var title: LocalizedStringResource = "Start Next Round"
    static var description = IntentDescription("Ends the rest phase and starts the next sauna round.")
    static var openAppWhenRun: Bool { false }

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        IntentDiagnostics.record("resume", "invoked")
        advanceRunningSession(from: "resume")
        return .result(actionButtonIntent: PauseSaunaWorkoutIntent())
    }
}
