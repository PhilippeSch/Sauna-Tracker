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
    @State private var pendingDeletion: SaunaSession?
    @State private var deletionError: String?
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
                    list
                }
            }
            .navigationTitle("History")
            .refreshable { await loadSessions() }
            .task { await loadSessions() }
            .onChange(of: connectivity.lastSavedWorkoutUUID) { _, _ in
                Task { await loadSessions() }
            }
            .confirmationDialog(
                "Delete this session?",
                isPresented: Binding(
                    get: { pendingDeletion != nil },
                    set: { if !$0 { pendingDeletion = nil } }
                ),
                titleVisibility: .visible,
                presenting: pendingDeletion
            ) { session in
                Button("Delete", role: .destructive) {
                    Task { await delete(session) }
                }
                Button("Cancel", role: .cancel) { pendingDeletion = nil }
            } message: { _ in
                Text("This removes it from Health as well and cannot be undone.")
            }
            .alert(
                "Could not delete",
                isPresented: Binding(
                    get: { deletionError != nil },
                    set: { if !$0 { deletionError = nil } }
                )
            ) {
                Button("OK", role: .cancel) { deletionError = nil }
            } message: {
                Text(deletionError ?? "")
            }
        }
    }

    private var list: some View {
        List(sessions) { session in
            NavigationLink {
                SessionDetailView(session: session) {
                    Task { await loadSessions() }
                }
            } label: {
                SessionRowView(session: session)
            }
            .swipeActions(edge: .trailing) {
                Button(role: .destructive) {
                    pendingDeletion = session
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }

    private func delete(_ session: SaunaSession) async {
        pendingDeletion = nil

        // Take the row out right away. Waiting for the HealthKit round-trip
        // first left the swiped-open row sitting under the dismissed dialog,
        // and it then vanished unanimated once the reload came back.
        let previousIndex = sessions.firstIndex { $0.id == session.id }
        withAnimation { sessions.removeAll { $0.id == session.id } }

        do {
            try await WorkoutHistoryStore.delete(session)
            await loadSessions()
        } catch {
            // Deletion failed, so put the row back where it was before saying so.
            if let previousIndex, previousIndex <= sessions.count {
                withAnimation { sessions.insert(session, at: previousIndex) }
            }
            deletionError = error.localizedDescription
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
