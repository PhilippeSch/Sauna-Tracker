//
//  WatchSettingsView.swift
//  Sauna Tracker Watch App
//
//  The settings worth changing while standing next to the sauna, without
//  reaching for the phone. Edits go through SettingsStore, so they persist
//  here and travel to the iPhone.
//

import SwiftUI

struct WatchSettingsView: View {
    @Bindable var store: SettingsStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Settings")
                    .font(.headline)
                    .padding(.top, 4)

                Toggle("Vibration", isOn: Binding(
                    get: { store.settings.hapticsEnabled },
                    set: { on in
                        store.modify { $0.hapticIntervalMinutes = on ? 5 : AppSettings.hapticsOff }
                    }
                ))
                .font(.system(size: 15))

                if store.settings.hapticsEnabled {
                    stepperRow(
                        title: "Every … min",
                        value: store.settings.hapticIntervalMinutes,
                        range: 1...AppSettings.hapticIntervalRange.upperBound
                    ) { newValue in
                        store.modify { $0.hapticIntervalMinutes = newValue }
                    }
                }

                metRow

                Text("Changes apply to the next session and sync to your iPhone.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)

                Text("Version \(AppVersion.displayString)")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 6)
            }
            .padding(.horizontal, 4)
        }
    }

    private func stepperRow(
        title: LocalizedStringKey,
        value: Int,
        range: ClosedRange<Int>,
        onChange: @escaping (Int) -> Void
    ) -> some View {
        Stepper(
            value: Binding(get: { value }, set: onChange),
            in: range
        ) {
            VStack(alignment: .leading, spacing: -2) {
                Text(title)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                Text("\(value)")
                    .font(.system(size: 17, weight: .semibold))
                    .monospacedDigit()
            }
        }
    }

    private var metRow: some View {
        Stepper(
            value: Binding(
                get: { store.settings.metValue },
                set: { newValue in store.modify { $0.metValue = newValue } }
            ),
            in: AppSettings.metRange,
            step: 0.05
        ) {
            VStack(alignment: .leading, spacing: -2) {
                Text("MET")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                Text(String(format: "%.2f", store.settings.metValue))
                    .font(.system(size: 17, weight: .semibold))
                    .monospacedDigit()
            }
        }
    }
}
