//
//  IntentDiagnosticsTests.swift
//  Sauna TrackerTests
//
//  The Action Button diagnostics are only worth anything if a recorded event
//  actually survives to be read back — that is the whole point of putting it
//  through UserDefaults rather than memory.
//

import Testing
import Foundation
@testable import Sauna_Tracker

@MainActor
struct IntentDiagnosticsTests {

    @Test func recordedEventsAreReadBack() {
        IntentDiagnostics.clear()
        defer { IntentDiagnostics.clear() }

        IntentDiagnostics.record("pause", "invoked")
        IntentDiagnostics.record("pause", "sauna -> rest")

        let events = IntentDiagnostics.load()
        #expect(events.count == 2)
        #expect(events.first?.name == "pause")
        #expect(events.first?.outcome == "invoked")
        #expect(events.last?.outcome == "sauna -> rest")
    }

    @Test func clearEmptiesTheLog() {
        IntentDiagnostics.record("toggle", "invoked")
        IntentDiagnostics.clear()
        #expect(IntentDiagnostics.load().isEmpty)
    }

    @Test func onlyTheMostRecentEventsAreKept() {
        IntentDiagnostics.clear()
        defer { IntentDiagnostics.clear() }

        for index in 0..<25 {
            IntentDiagnostics.record("pause", "event \(index)")
        }

        let events = IntentDiagnostics.load()
        #expect(events.count <= 10, "the log is bounded so it cannot grow forever")
        #expect(events.last?.outcome == "event 24", "and keeps the newest, not the oldest")
    }
}
