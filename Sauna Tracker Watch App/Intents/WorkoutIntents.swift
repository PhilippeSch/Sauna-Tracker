//
//  WorkoutIntents.swift
//  Sauna Tracker Watch App
//
//  What makes the Action Button on Apple Watch Ultra usable for a sauna
//  session. The button's "Workout" action is not something an app can grab
//  directly: watchOS drives it through the system workout intents, and an app
//  becomes selectable for it by adopting them.
//
//  Pause and Resume both simply advance the phase. The tidier mapping would
//  be Pause -> Rest and Resume -> Sauna, but the system decides which of the
//  two to send from the HKWorkoutSession's own state, and we deliberately
//  never pause that session — pausing would stop heart rate collection, and
//  we record pulse through the rest phase too. So the app cannot rely on the
//  two alternating, and each press just toggles.
//

import AppIntents
import Foundation
import os

private let intentLog = Logger(subsystem: "Scheuber.Sauna-Tracker", category: "Intents")

/// Advances the phase of the running session, if there is one.
/// Returns what happened so the intents can log it — an Action Button press
/// that does nothing is otherwise invisible from the outside.
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

/// The Action Button's workout picker needs something to name; a sauna
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
        guard let store = SessionStore.current else {
            intentLog.error("start: no live session store registered")
            IntentDiagnostics.record("start", "no store")
            return .result()
        }
        if store.isActive {
            // The button was pressed to move the session on, not to begin one.
            advanceRunningSession(from: "start(already running)")
        } else {
            await store.startSession()
            intentLog.info("start: session started")
            IntentDiagnostics.record("start", "session started")
        }
        return .result()
    }
}

struct PauseSaunaWorkoutIntent: AppIntent, PauseWorkoutIntent {
    static var title: LocalizedStringResource = "Switch Sauna Phase"
    static var description = IntentDescription("Switches between the sauna round and the rest phase.")
    static var openAppWhenRun: Bool = false

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        IntentDiagnostics.record("pause", "invoked")
        advanceRunningSession(from: "pause")
        return .result()
    }
}

struct ResumeSaunaWorkoutIntent: AppIntent, ResumeWorkoutIntent {
    static var title: LocalizedStringResource = "Switch Sauna Phase"
    static var description = IntentDescription("Switches between the sauna round and the rest phase.")
    static var openAppWhenRun: Bool = false

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        IntentDiagnostics.record("resume", "invoked")
        advanceRunningSession(from: "resume")
        return .result()
    }
}
