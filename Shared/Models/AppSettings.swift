//
//  AppSettings.swift
//  Sauna Tracker
//
//  User-configurable defaults. Lives locally on each device (AppStorage on
//  iOS driving a mirrored copy on the Watch via WatchConnectivity) — never
//  written to HealthKit, since it isn't health data.
//

import Foundation

struct AppSettings: Codable, Sendable, Equatable {
    var metValue: Double
    var maxRounds: Int
    var bodyWeightOverrideKg: Double?
    var hapticIntervalMinutes: Int

    static let `default` = AppSettings(
        metValue: 1.75,
        maxRounds: 5,
        bodyWeightOverrideKg: nil,
        hapticIntervalMinutes: 5
    )

    /// Used only when HealthKit has no body mass sample and the user set no
    /// override — an average adult weight, so calories are a rough estimate
    /// instead of nothing at all.
    static let fallbackBodyWeightKg: Double = 75

    static let metRange: ClosedRange<Double> = 1.5...2.0
    static let maxRoundsRange: ClosedRange<Int> = 1...10
    static let hapticIntervalRange: ClosedRange<Int> = 1...15
}
