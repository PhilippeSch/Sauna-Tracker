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
    /// Plausible adult body weights. A value outside this is a typo — a
    /// missing digit or one too many — and is rejected rather than stored.
    static let bodyWeightRangeKg: ClosedRange<Double> = 30...250

    /// Reads a body weight the way the user typed it.
    ///
    /// `Double("80,5")` is nil: that initialiser only understands the C
    /// format with a dot, while the decimal pad on German, Swedish and
    /// Finnish keyboards produces a comma — three of the four languages this
    /// app ships in. Both separators are accepted here, and the result must
    /// fall inside `bodyWeightRangeKg` to count.
    static func parsedBodyWeightKg(_ text: String, locale: Locale = .current) -> Double? {
        let normalised = text
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: locale.decimalSeparator ?? ".", with: ".")
            .replacingOccurrences(of: ",", with: ".")
        guard let value = Double(normalised), bodyWeightRangeKg.contains(value) else { return nil }
        return value
    }

    /// Renders a weight back into the field with the separator the keyboard
    /// will offer, so an edited value round-trips instead of turning into
    /// something the user cannot retype.
    static func bodyWeightText(_ kg: Double, locale: Locale = .current) -> String {
        String(format: "%g", kg)
            .replacingOccurrences(of: ".", with: locale.decimalSeparator ?? ".")
    }
}
