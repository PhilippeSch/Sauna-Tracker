//
//  AppSettings.swift
//  Sauna Companion
//
//  User-configurable defaults. Lives locally on each device (AppStorage on
//  iOS driving a mirrored copy on the Watch via WatchConnectivity) — never
//  written to HealthKit, since it isn't health data.
//

import Foundation

struct AppSettings: Codable, Sendable, Equatable {
    var metValue: Double
    var bodyWeightOverrideKg: Double?
    /// Minutes between reminder taps, or `hapticsOff` for none at all.
    var hapticIntervalMinutes: Int

    /// Sentinel for "no vibration at all", distinct from a short interval.
    static let hapticsOff = 0

    var hapticsEnabled: Bool { hapticIntervalMinutes > Self.hapticsOff }

    static let `default` = AppSettings(
        metValue: 1.75,
        bodyWeightOverrideKg: nil,
        hapticIntervalMinutes: 5
    )

    /// Used only when HealthKit has no body mass sample and the user set no
    /// override — an average adult weight, so calories are a rough estimate
    /// instead of nothing at all.
    static let fallbackBodyWeightKg: Double = 75

    static let metRange: ClosedRange<Double> = 1.5...2.0
    /// Starts at 0 so vibration can be switched off entirely.
    static let hapticIntervalRange: ClosedRange<Int> = 0...15
}
