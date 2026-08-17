//
//  HistoryListView.swift
//  Sauna Tracker
//
//  Reads sessions straight out of HealthKit — no local cache, HealthKit is
//  the only store. Refreshes when the Watch pings that a new session saved.
//

import SwiftUI

struct HistoryListView: View {
    @State private var sessions: [SaunaSession] = []
    @State private var isLoading = true
    private let connectivity = WatchConnectivityService.shared

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                } else if sessions.isEmpty {
                    ContentUnavailableView(
                        "No Sessions Yet",
                        systemImage: "flame",
                        description: Text("Start a session on your Apple Watch to see it here.")
                    )
                } else {
                    List(sessions) { session in
                        SessionRowView(session: session)
                    }
                }
            }
            .navigationTitle("History")
            .refreshable { await loadSessions() }
            .task { await loadSessions() }
            .onChange(of: connectivity.lastSavedWorkoutUUID) { _, _ in
                Task { await loadSessions() }
            }
        }
    }

    private func loadSessions() async {
        sessions = await WorkoutHistoryStore.fetchAllSessions()
        isLoading = false
    }
}

#Preview {
    HistoryListView()
}
