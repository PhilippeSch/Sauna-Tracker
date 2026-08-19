//
//  IntentDiagnostics.swift
//  Sauna Tracker
//
//  A visible record of Action Button activity, so the button can be debugged
//  on the wrist instead of through Console.app.
//
//  Deliberately written through UserDefaults rather than kept in memory: if
//  watchOS runs an App Intent in a different process from the one drawing the
//  screen, an in-memory log would stay empty and prove nothing, whereas this
//  survives into whichever process shows it.
//

import Foundation

enum IntentDiagnostics {
    private static let key = "saunaTracker.intentLog.v1"
    private static let limit = 10

    struct Event: Codable, Identifiable, Equatable {
        var id = UUID()
        var date: Date
        var name: String
        var outcome: String
    }

    /// Called as the very first statement of every intent, before any guard,
    /// so "the intent never ran" and "the intent ran and bailed out" cannot be
    /// confused with each other.
    static func record(_ name: String, _ outcome: String) {
        let defaults = UserDefaults.standard
        var events = load()
        events.append(Event(date: .now, name: name, outcome: outcome))
        events = Array(events.suffix(limit))
        if let data = try? JSONEncoder().encode(events) {
            defaults.set(data, forKey: key)
        }
    }

    static func load() -> [Event] {
        guard
            let data = UserDefaults.standard.data(forKey: key),
            let events = try? JSONDecoder().decode([Event].self, from: data)
        else { return [] }
        return events
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
