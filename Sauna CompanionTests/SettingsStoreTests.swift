//
//  SettingsStoreTests.swift
//  Sauna CompanionTests
//
//  Both devices may edit settings, so the rules that stop them fighting are
//  worth pinning down: a local edit is pushed, a remote edit is not echoed,
//  and either survives a relaunch.
//

import Testing
import Foundation
@testable import Sauna_Companion

@MainActor
struct SettingsStoreTests {

    /// A throwaway UserDefaults so suites cannot see each other's writes.
    private func makeDefaults() -> UserDefaults {
        let suite = "settings.tests.\(UUID().uuidString)"
        return UserDefaults(suiteName: suite)!
    }

    @Test func startsFromDefaultsWhenNothingWasStored() {
        let store = SettingsStore(defaults: makeDefaults(), push: { _ in })
        #expect(store.settings == AppSettings.default)
    }

    @Test func localEditIsPushedToTheOtherDevice() {
        var pushed: [AppSettings] = []
        let store = SettingsStore(defaults: makeDefaults(), push: { pushed.append($0) })

        store.modify { $0.hapticIntervalMinutes = 3 }

        #expect(store.settings.hapticIntervalMinutes == 3)
        #expect(pushed.count == 1)
        #expect(pushed.first?.hapticIntervalMinutes == 3)
    }

    @Test func remoteEditIsStoredButNotEchoedBack() {
        var pushed: [AppSettings] = []
        let store = SettingsStore(defaults: makeDefaults(), push: { pushed.append($0) })

        var incoming = AppSettings.default
        incoming.hapticIntervalMinutes = 2
        store.applyRemote(incoming)

        #expect(store.settings.hapticIntervalMinutes == 2)
        #expect(pushed.isEmpty, "echoing a remote change would ping-pong between the devices")
    }

    @Test func settingAnUnchangedValueDoesNotPush() {
        var pushed: [AppSettings] = []
        let store = SettingsStore(defaults: makeDefaults(), push: { pushed.append($0) })

        store.update(AppSettings.default)
        store.modify { $0.hapticIntervalMinutes = AppSettings.default.hapticIntervalMinutes }

        #expect(pushed.isEmpty)
    }

    @Test func changesSurviveARelaunch() {
        let defaults = makeDefaults()
        let first = SettingsStore(defaults: defaults, push: { _ in })
        first.modify { $0.hapticIntervalMinutes = AppSettings.hapticsOff }
        first.modify { $0.metValue = 1.9 }

        let second = SettingsStore(defaults: defaults, push: { _ in })
        #expect(second.settings.hapticsEnabled == false)
        #expect(second.settings.metValue == 1.9)
    }

    @Test func vibrationOffIsDistinctFromAShortInterval() {
        var settings = AppSettings.default
        settings.hapticIntervalMinutes = 1
        #expect(settings.hapticsEnabled)

        settings.hapticIntervalMinutes = AppSettings.hapticsOff
        #expect(settings.hapticsEnabled == false)
    }
}
