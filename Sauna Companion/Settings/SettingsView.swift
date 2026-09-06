//
//  SettingsView.swift
//  Sauna Companion
//
//  Edits go through SettingsStore, which persists them and mirrors them to
//  the watch. The watch can edit the same values, and changes made there
//  arrive here the same way.
//
//  App language is not a custom switcher: it deep-links to the system
//  per-app language picker, which is where the four supported languages
//  actually live.
//

import SwiftUI

struct SettingsView: View {
    @Bindable private var store = SettingsStore.shared
    @State private var weightText: String = ""
    @FocusState private var weightFocused: Bool

    private var settings: AppSettings { store.settings }

    var body: some View {
        NavigationStack {
            Form {
                Section("Calorie Estimate") {
                    VStack(alignment: .leading) {
                        Text("MET Value: \(settings.metValue, specifier: "%.2f")")
                        Slider(
                            value: Binding(
                                get: { settings.metValue },
                                set: { newValue in store.modify { $0.metValue = newValue } }
                            ),
                            in: AppSettings.metRange,
                            step: 0.05
                        )
                    }
                }

                Section {
                    Toggle("Vibration", isOn: Binding(
                        get: { settings.hapticsEnabled },
                        set: { on in
                            store.modify { $0.hapticIntervalMinutes = on ? 5 : AppSettings.hapticsOff }
                        }
                    ))

                    if settings.hapticsEnabled {
                        Stepper(
                            "Haptic Every \(settings.hapticIntervalMinutes) min",
                            value: Binding(
                                get: { settings.hapticIntervalMinutes },
                                set: { newValue in store.modify { $0.hapticIntervalMinutes = newValue } }
                            ),
                            in: 1...AppSettings.hapticIntervalRange.upperBound
                        )
                    }
                } header: {
                    Text("Session")
                } footer: {
                    if !settings.hapticsEnabled {
                        Text("No taps during a session.")
                    }
                }

                Section("Body Weight") {
                    Toggle("Override HealthKit Weight", isOn: Binding(
                        get: { settings.bodyWeightOverrideKg != nil },
                        set: { on in
                            store.modify {
                                $0.bodyWeightOverrideKg = on
                                    ? (AppSettings.parsedBodyWeightKg(weightText) ?? AppSettings.fallbackBodyWeightKg)
                                    : nil
                            }
                        }
                    ))

                    if settings.bodyWeightOverrideKg != nil {
                        HStack {
                            Text("Weight (kg)")
                            Spacer()
                            TextField("kg", text: $weightText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                                .focused($weightFocused)
                                // Committing per keystroke pushed a fresh
                                // application context to the watch for every
                                // digit — two of them just to type "80". The
                                // value is taken once the field is done with.
                                .onSubmit(commitWeight)
                                .onChange(of: weightFocused) { _, focused in
                                    if !focused { commitWeight() }
                                }
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
                            Text("App Language").foregroundStyle(.primary)
                            Spacer()
                            Text(Locale.current.language.languageCode?.identifier.uppercased() ?? "")
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section {
                } footer: {
                    Text("Version \(AppVersion.displayString)")
                        .font(.footnote)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                weightText = AppSettings.bodyWeightText(
                    settings.bodyWeightOverrideKg ?? AppSettings.fallbackBodyWeightKg
                )
            }
        }
    }

    private func commitWeight() {
        guard settings.bodyWeightOverrideKg != nil,
              let value = AppSettings.parsedBodyWeightKg(weightText)
        else { return }
        store.modify { $0.bodyWeightOverrideKg = value }
    }
}

#Preview {
    SettingsView()
}
