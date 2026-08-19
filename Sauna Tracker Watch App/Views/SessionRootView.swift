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
    private var settings = SettingsStore.shared

    var body: some View {
        NavigationStack {
            switch store.stage {
            case .idle:
                IdlePager(store: store, settings: settings)
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
        // Settings can change on either device; keep the running session in
        // step with whatever the store currently holds.
        .onChange(of: settings.settings) { _, newSettings in
            store.applySettings(newSettings)
        }
        .task {
            store.applySettings(settings.settings)
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
