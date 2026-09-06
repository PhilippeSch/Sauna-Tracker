//
//  IdlePager.swift
//  Sauna Companion Watch App
//
//  The start screen, with settings tucked one swipe to the right so the
//  first thing you see is still a single big Start button.
//

import SwiftUI

struct IdlePager: View {
    @Bindable var store: SessionStore
    @Bindable var settings: SettingsStore

    // Settings sits left of the start screen, which starts selected — so the
    // gesture that reaches it is a swipe to the right.
    @State private var selection = 1

    var body: some View {
        TabView(selection: $selection) {
            WatchSettingsView(store: settings)
                .tag(0)
            StartSessionView(store: store)
                .tag(1)
        }
        .tabViewStyle(.page)
    }
}
