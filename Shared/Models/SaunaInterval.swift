//
//  SaunaInterval.swift
//  Sauna Tracker
//
//  One contiguous Sauna or Rest segment within a Session.
//

import Foundation

struct SaunaInterval: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var phase: SaunaPhase
    var startDate: Date
    var endDate: Date
    var maxHeartRateBPM: Double?
    var sensorReadings: RoundSensorReadings

    init(
        id: UUID = UUID(),
        phase: SaunaPhase,
        startDate: Date,
        endDate: Date,
        maxHeartRateBPM: Double? = nil,
        sensorReadings: RoundSensorReadings = .empty
    ) {
        self.id = id
        self.phase = phase
        self.startDate = startDate
        self.endDate = endDate
        self.maxHeartRateBPM = maxHeartRateBPM
        self.sensorReadings = sensorReadings
    }

    var duration: TimeInterval { endDate.timeIntervalSince(startDate) }
}
