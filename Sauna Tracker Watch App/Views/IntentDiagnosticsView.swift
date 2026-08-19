//
//  IntentDiagnosticsView.swift
//  Sauna Tracker Watch App
//
//  Temporary instrumentation for the Action Button investigation. Shows what
//  the App Intents actually did, on the wrist, so the button can be tested
//  without attaching the watch to Console.app.
//
//  Reading:
//    (empty)         the intent never ran — the press is not reaching the app
//    "no store"      it ran, but in a context with no registered session
//    "store idle"    it ran, but no session was in progress
//    "sauna -> rest" it worked
//
//  Remove this view, IntentDiagnostics and the record() calls once the button
//  is confirmed working.
//

import SwiftUI

struct IntentDiagnosticsView: View {
    @State private var events: [IntentDiagnostics.Event] = []

    private static let time: Date.FormatStyle = .dateTime.hour().minute().second()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                Text("Action Button")
                    .font(.headline)

                if events.isEmpty {
                    Text("No intent has run yet. Press the Action button, then come back to this page.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(events.reversed()) { event in
                        VStack(alignment: .leading, spacing: 0) {
                            HStack {
                                Text(event.name)
                                    .font(.system(size: 13, weight: .semibold))
                                Spacer()
                                Text(event.date, format: Self.time)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                            Text(event.outcome)
                                .font(.system(size: 12))
                                .foregroundStyle(event.outcome.contains("->") ? .green : .yellow)
                        }
                    }

                    Button("Clear") {
                        IntentDiagnostics.clear()
                        events = []
                    }
                    .font(.system(size: 13))
                    .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
            .padding(.top, 6)
        }
        // Re-read rather than observe: the writer may be a different process.
        .onAppear { events = IntentDiagnostics.load() }
        .task {
            while !Task.isCancelled {
                events = IntentDiagnostics.load()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }
}
