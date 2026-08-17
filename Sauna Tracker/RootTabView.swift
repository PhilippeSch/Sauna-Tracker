//
//  RootTabView.swift
//  Sauna Tracker
//

import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            HistoryListView()
                .tabItem {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
    }
}

#Preview {
    RootTabView()
}
