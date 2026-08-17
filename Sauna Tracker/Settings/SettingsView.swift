//
//  SettingsView.swift
//  Sauna Tracker
//
//  Settings live locally on the phone (AppStorage) and get pushed to the
//  Watch via WatchConnectivity whenever they change. App language isn't a
//  custom in-app switcher — it deep-links to the system per-app language
//  picker, which is where our 4 supported languages (en/de/sv/fi) actually
//  live once localized.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("settings.metValue") private var metValue = AppSettings.default.metValue
    @AppStorage("settings.maxRounds") private var maxRounds = AppSettings.default.maxRounds
    @AppStorage("settings.hapticIntervalMinutes") private var hapticIntervalMinutes = AppSettings.default.hapticIntervalMinutes
    @AppStorage("settings.bodyWeightOverrideEnabled") private var bodyWeightOverrideEnabled = false
    @AppStorage("settings.bodyWeightOverrideKg") private var bodyWeightOverrideKg = 75.0

    var body: some View {
        NavigationStack {
            Form {
                Section("Calorie Estimate") {
                    VStack(alignment: .leading) {
                        Text("MET Value: \(metValue, specifier: "%.2f")")
                        Slider(value: $metValue, in: AppSettings.metRange, step: 0.05)
                    }
                }

                Section("Session") {
                    Stepper("Max Rounds: \(maxRounds)", value: $maxRounds, in: AppSettings.maxRoundsRange)
                    Stepper("Haptic Every \(hapticIntervalMinutes) min", value: $hapticIntervalMinutes, in: AppSettings.hapticIntervalRange)
                }

                Section("Body Weight") {
                    Toggle("Override HealthKit Weight", isOn: $bodyWeightOverrideEnabled)
                    if bodyWeightOverrideEnabled {
                        HStack {
                            Text("Weight (kg)")
                            Spacer()
                            TextField("kg", value: $bodyWeightOverrideKg, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                        }
                    }
                }

                Section("Language") {
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        HStack {
                            Text("App Language")
                                .foregroundStyle(.primary)
                            Spacer()
                            Text(Locale.current.language.languageCode?.identifier.uppercased() ?? "")
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .onChange(of: metValue) { _, _ in pushSettings() }
            .onChange(of: maxRounds) { _, _ in pushSettings() }
            .onChange(of: hapticIntervalMinutes) { _, _ in pushSettings() }
            .onChange(of: bodyWeightOverrideEnabled) { _, _ in pushSettings() }
            .onChange(of: bodyWeightOverrideKg) { _, _ in pushSettings() }
            .task { pushSettings() }
        }
    }

    private func pushSettings() {
        let settings = AppSettings(
            metValue: metValue,
            maxRounds: maxRounds,
            bodyWeightOverrideKg: bodyWeightOverrideEnabled ? bodyWeightOverrideKg : nil,
            hapticIntervalMinutes: hapticIntervalMinutes
        )
        WatchConnectivityService.shared.sendSettings(settings)
    }
}

#Preview {
    SettingsView()
}
