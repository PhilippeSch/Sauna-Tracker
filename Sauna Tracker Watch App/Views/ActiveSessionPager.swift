//
//  ActiveSessionPager.swift
//  Sauna Tracker Watch App
//
//  Holds the two pages of a running session — metrics, and swipe-left for
//  controls — and owns the single "really end?" confirmation both pages
//  trigger. Under Always-On the pages collapse to one dim summary view.
//

import SwiftUI
import WatchKit

struct ActiveSessionPager: View {
    /// The metrics page — the one worth being locked onto during a round.
    private static let metricsPage = 0

    @Environment(\.isLuminanceReduced) private var isLuminanceReduced
    @Bindable var store: SessionStore

    @State private var selection = ActiveSessionPager.metricsPage
    @State private var showingEndConfirmation = false

    var body: some View {
        Group {
            if isLuminanceReduced {
                AlwaysOnSessionView(store: store)
            } else {
                TabView(selection: $selection) {
                    ActiveSessionView(store: store)
                        .tag(0)
                    SessionControlsView(
                        store: store,
                        onEndRequested: { showingEndConfirmation = true },
                        // Water Lock kills the touchscreen, so the page has to
                        // change before it is engaged — otherwise you are stuck
                        // staring at the controls for the rest of the round.
                        onWaterLockRequested: {
                            selection = Self.metricsPage
                            WKInterfaceDevice.current().enableWaterLock()
                        }
                    )
                    .tag(1)
                }
                .tabViewStyle(.page)
            }
        }
        // Only in Always-On, where the title sits quietly top-left. On the
        // live screen it crowded the timer without adding anything the
        // phase-coloured timer doesn't already say.
        .navigationTitle(isLuminanceReduced ? store.currentPhase.displayName : "")
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
