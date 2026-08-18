//
//  ActiveSessionPager.swift
//  Sauna Tracker Watch App
//
//  Holds the two pages of a running session — metrics, and swipe-left for
//  controls — and owns the single "really end?" confirmation both pages
//  trigger. Under Always-On the pages collapse to one dim summary view.
//

import SwiftUI

struct ActiveSessionPager: View {
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced
    @Bindable var store: SessionStore

    @State private var selection = 0
    @State private var showingEndConfirmation = false

    var body: some View {
        Group {
            if isLuminanceReduced {
                AlwaysOnSessionView(store: store)
            } else {
                TabView(selection: $selection) {
                    ActiveSessionView(store: store) { showingEndConfirmation = true }
                        .tag(0)
                    SessionControlsView(store: store) { showingEndConfirmation = true }
                        .tag(1)
                }
                .tabViewStyle(.page)
            }
        }
        .navigationTitle(store.currentPhase.displayName)
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
