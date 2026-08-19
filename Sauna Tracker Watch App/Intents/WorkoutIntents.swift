//
//  WorkoutIntents.swift
//  Sauna Tracker Watch App
//
//  What makes the Action Button on Apple Watch Ultra usable for a sauna
//  session. The button's "Workout" action is not something an app can grab
//  directly: watchOS drives it through the system workout intents, and an app
//  becomes selectable for it by adopting them.
//
//  The mapping onto our phases falls out naturally, because a sauna round is
//  the "running" state and a rest phase is the "paused" one:
//
//      StartWorkoutIntent   -> start a session (first sauna round)
//      PauseWorkoutIntent   -> switch to Rest
//      ResumeWorkoutIntent  -> switch to the next Sauna round
//
//  So during a session the Action Button toggles sauna/rest, which is what
//  the on-screen primary button does.
//

import AppIntents
import Foundation

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
        if let store = SessionStore.current, !store.isActive {
            await store.startSession()
        }
        return .result()
    }
}

/// Action Button while a round is running: go into the rest phase.
struct PauseSaunaWorkoutIntent: AppIntent, PauseWorkoutIntent {
    static var title: LocalizedStringResource = "Start Rest Phase"
    static var description = IntentDescription("Ends the current sauna round and starts the rest phase.")
    static var openAppWhenRun: Bool = false

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        if let store = SessionStore.current, store.isActive, store.currentPhase == .sauna {
            store.advancePhase()
        }
        return .result()
    }
}

/// Action Button while resting: start the next round.
struct ResumeSaunaWorkoutIntent: AppIntent, ResumeWorkoutIntent {
    static var title: LocalizedStringResource = "Start Next Round"
    static var description = IntentDescription("Ends the rest phase and starts the next sauna round.")
    static var openAppWhenRun: Bool = false

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        if let store = SessionStore.current, store.isActive, store.currentPhase == .rest {
            store.advancePhase()
        }
        return .result()
    }
}
