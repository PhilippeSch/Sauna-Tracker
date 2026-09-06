//
//  SettingsStore.swift
//  Sauna Companion
//
//  One settings value per device, persisted locally and mirrored to the
//  other device. Either side may edit: a local edit is pushed across, an
//  arriving edit is stored without being echoed back, so the two cannot
//  ping-pong. Local persistence also means the watch keeps working with the
//  right settings before it has ever heard from the phone.
//

import Foundation
import Observation

@MainActor
@Observable
final class SettingsStore {
    static let shared = SettingsStore()

    private static let defaultsKey = "saunaTracker.settings.v1"

    private(set) var settings: AppSettings

    private let defaults: UserDefaults
    private let push: (AppSettings) -> Void

    // `push` defaults inside the body rather than in the signature: a default
    // argument is evaluated in a nonisolated context, and both
    // WatchConnectivityService.shared and sendSettings are main-actor bound —
    // an error under the Swift 6 language mode.
    init(
        defaults: UserDefaults = .standard,
        push: ((AppSettings) -> Void)? = nil
    ) {
        self.defaults = defaults
        self.push = push ?? { settings in
            WatchConnectivityService.shared.sendSettings(settings)
        }
        self.settings = Self.load(from: defaults) ?? .default
    }

    /// A change made on this device: persist it and tell the other one.
    func update(_ newValue: AppSettings) {
        guard newValue != settings else { return }
        settings = newValue
        persist()
        push(newValue)
    }

    /// A change that arrived from the other device: persist it, do not echo.
    func applyRemote(_ newValue: AppSettings) {
        guard newValue != settings else { return }
        settings = newValue
        persist()
    }

    /// Convenience for editing one field at a time from a form.
    func modify(_ change: (inout AppSettings) -> Void) {
        var copy = settings
        change(&copy)
        update(copy)
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: Self.defaultsKey)
    }

    private static func load(from defaults: UserDefaults) -> AppSettings? {
        guard let data = defaults.data(forKey: defaultsKey) else { return nil }
        return try? JSONDecoder().decode(AppSettings.self, from: data)
    }
}
