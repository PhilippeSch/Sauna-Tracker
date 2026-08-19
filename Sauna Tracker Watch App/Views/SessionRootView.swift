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
            // Registers the instance SwiftUI actually kept. Doing this from
            // the store's init pointed App Intents at a discarded copy.
            store.makeCurrent()
            store.applySettings(settings.settings)

            // The Action button can start a session before the UI exists to
            // register a store; finish that start now that it does.
            if PendingSessionStart.isRequested {
                PendingSessionStart.isRequested = false
                if !store.isActive {
                    IntentDiagnostics.record("start", "resumed after launch")
                    await store.startSession()
                }
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
