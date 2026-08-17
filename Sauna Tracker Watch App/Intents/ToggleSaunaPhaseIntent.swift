//
//  ToggleSaunaPhaseIntent.swift
//  Sauna Tracker Watch App
//
//  Registered as an App Shortcut so it's selectable from Watch Settings ->
//  Action Button (Apple Watch Ultra). Reaches the live SessionStore via its
//  weak `current` reference; if there's no active session it's a no-op.
//

import AppIntents

struct ToggleSaunaPhaseIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Sauna Phase"
    static var description = IntentDescription(
        "Switches between the Sauna and Rest phase of the current sauna session."
    )
    static var openAppWhenRun: Bool = false

    @MainActor
    func perform() async throws -> some IntentResult {
        if let store = SessionStore.current, store.isActive {
            store.advancePhase()
        }
        return .result()
    }
}

struct SaunaTrackerShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ToggleSaunaPhaseIntent(),
            phrases: ["Toggle sauna phase in \(.applicationName)"],
            shortTitle: "Toggle Phase",
            systemImageName: "flame.fill"
        )
    }
}
