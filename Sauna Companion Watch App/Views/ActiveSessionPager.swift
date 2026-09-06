//
//  ActiveSessionPager.swift
//  Sauna Companion Watch App
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
        // No navigation title on either screen: the live one is carried by the
        // phase-coloured timer, and in Always-On the coloured label in the
        // middle already names the phase — a title there just said it twice.
        .navigationTitle("")
        .confirmationDialog(
            "End this sauna session?",
            isPresented: $showingEndConfirmation,
            titleVisibility: .visible
        ) {
            // No destructive role: ending a session saves it. Red here put it
            // in the same visual class as discarding, which is the one action
            // on this sheet that actually loses data.
            Button("End Session") {
                Task { await store.endSession() }
            }
            // Deliberately the second entry, never the first: throwing a
            // session away is the rare case, and it must not be the button
            // that falls under a thumb aiming for the one that saves it.
            Button("Delete Session", role: .destructive) {
                Task { await store.discardSession() }
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}
