//
//  SensorReadings.swift
//  Sauna Tracker
//
//  Optional, best-effort sensor snapshot captured for a single round.
//  Every field is nil unless a genuinely fresh HealthKit sample existed —
//  see the plan notes on SpO2 / wrist temperature availability.
//

import Foundation

struct RoundSensorReadings: Codable, Hashable, Sendable {
    var hrv: Double?               // ms, heartRateVariabilitySDNN
    var respiratoryRate: Double?   // breaths/min
    var spo2: Double?              // fraction 0-1
    var wristTemperatureC: Double?

    var hasAnyReading: Bool {
        hrv != nil || respiratoryRate != nil || spo2 != nil || wristTemperatureC != nil
    }

    static let empty = RoundSensorReadings()
}
