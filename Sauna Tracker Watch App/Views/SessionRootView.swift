//
//  SessionRootView.swift
//  Sauna Tracker Watch App
//

import SwiftUI

struct SessionRootView: View {
    @State private var store = SessionStore()

    var body: some View {
        NavigationStack {
            Group {
                switch store.stage {
                case .idle:
                    StartSessionView(store: store)
                case .active:
                    ActiveSessionView(store: store)
                case .summary(let session):
                    EndSessionSummaryView(
                        session: session,
                        errorDescription: store.lastErrorDescription,
                        onDone: { store.reset() }
                    )
                }
            }
        }
        .onChange(of: WatchConnectivityService.shared.latestSettings) { _, newSettings in
            if let newSettings {
                store.applySettings(newSettings)
            }
        }
        .task {
            if let settings = WatchConnectivityService.shared.latestSettings {
                store.applySettings(settings)
            }
        }
    }
}
