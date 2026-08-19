//
//  SessionRootView.swift
//  Sauna Tracker Watch App
//

import SwiftUI

struct SessionRootView: View {
    @State private var store = SessionStore(
        recorder: HealthKitSessionRecorder(),
        hapticScheduler: HapticScheduler()
    )

    var body: some View {
        NavigationStack {
            switch store.stage {
            case .idle:
                StartSessionView(store: store)
            case .active:
                ActiveSessionPager(store: store)
            case .saving:
                SavingSessionView()
            case .summary(let session):
                EndSessionSummaryView(
                    session: session,
                    errorDescription: store.lastErrorDescription,
                    onDone: { store.reset() }
                )
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

struct SavingSessionView: View {
    var body: some View {
        VStack(spacing: 10) {
            ProgressView()
            Text("Saving…")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
