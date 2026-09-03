//
//  SessionRootView.swift
//  Sauna Tracker Watch App
//

import SwiftUI

struct SessionRootView: View {
    @Bindable var store: SessionStore
    private var settings = SettingsStore.shared

    /// The Action button has to be pointed at this app in Settings, which is
    /// worth saying once on the models that have one.
    @AppStorage("saunaTracker.hasSeenActionButtonInfo") private var hasSeenActionButtonInfo = false
    @State private var showingActionButtonInfo = false

    init(store: SessionStore) {
        self.store = store
    }

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
        .sheet(isPresented: $showingActionButtonInfo) {
            // Also covers a swipe-down dismissal, so it never comes back.
            hasSeenActionButtonInfo = true
        } content: {
            ActionButtonInfoView { showingActionButtonInfo = false }
        }
        .task {
            // Re-asserts the registration made at launch, against the instance
            // the UI actually kept.
            store.makeCurrent()
            store.applySettings(settings.settings)

            // The Action button can start a session before there is a store to
            // act on; finish that start now that there is one.
            if PendingSessionStart.isRequested {
                PendingSessionStart.isRequested = false
                if !store.isActive {
                    await store.startSession()
                }
            }

            showingActionButtonInfo = !hasSeenActionButtonInfo && WatchHardware.hasActionButton
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
