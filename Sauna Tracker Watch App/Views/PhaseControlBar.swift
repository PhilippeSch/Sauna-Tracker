//
//  PhaseControlBar.swift
//  Sauna Tracker Watch App
//

import SwiftUI

struct PhaseControlBar: View {
    @Bindable var store: SessionStore
    @State private var showingEndConfirmation = false

    var body: some View {
        VStack(spacing: 6) {
            Button {
                store.advancePhase()
            } label: {
                Text(store.currentPhase == .sauna ? "Rest" : "Next Round")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(store.currentPhase.tintColor)
            .disabled(store.currentPhase == .rest && !store.canStartAnotherRound)

            Button(role: .destructive) {
                showingEndConfirmation = true
            } label: {
                Text("End Session")
                    .font(.footnote)
            }
            .buttonStyle(.bordered)
        }
        .confirmationDialog(
            "End this sauna session?",
            isPresented: $showingEndConfirmation,
            titleVisibility: .visible
        ) {
            Button("End Session", role: .destructive) {
                Task { await store.endSession() }
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}
