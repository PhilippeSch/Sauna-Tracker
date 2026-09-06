//
//  RootTabView.swift
//  Sauna Companion
//

import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            StatsView()
                .tabItem {
                    Label("Statistics", systemImage: "chart.bar.fill")
                }

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
