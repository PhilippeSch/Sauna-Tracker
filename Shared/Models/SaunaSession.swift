//
//  SaunaSession.swift
//  Sauna Companion
//
//  A full sauna visit: one or more Sauna/Rest intervals, saved as a single
//  HKWorkout. This is the in-memory representation used while recording on
//  the Watch and when reading history back on either device.
//

import Foundation

struct SaunaSession: Identifiable, Codable, Sendable {
    let id: UUID
    var startDate: Date
    var endDate: Date
    var intervals: [SaunaInterval]
    var notes: String?
    var metUsed: Double
    var activeEnergyKcal: Double?
    var healthKitWorkoutUUID: UUID?

    init(
        id: UUID = UUID(),
        startDate: Date,
        endDate: Date,
        intervals: [SaunaInterval],
        notes: String? = nil,
        metUsed: Double,
        activeEnergyKcal: Double? = nil,
        healthKitWorkoutUUID: UUID? = nil
    ) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.intervals = intervals
        self.notes = notes
        self.metUsed = metUsed
        self.activeEnergyKcal = activeEnergyKcal
        self.healthKitWorkoutUUID = healthKitWorkoutUUID
    }

    var saunaRounds: [SaunaInterval] { intervals.filter { $0.phase == .sauna } }
    var restIntervals: [SaunaInterval] { intervals.filter { $0.phase == .rest } }
    var roundCount: Int { saunaRounds.count }

    var totalSaunaDuration: TimeInterval {
        saunaRounds.reduce(0) { $0 + $1.duration }
    }

    var totalRestDuration: TimeInterval {
        restIntervals.reduce(0) { $0 + $1.duration }
    }

    var totalDuration: TimeInterval { endDate.timeIntervalSince(startDate) }

    var averageRoundDuration: TimeInterval {
        guard !saunaRounds.isEmpty else { return 0 }
        return totalSaunaDuration / Double(saunaRounds.count)
    }

    var maxHeartRateBPM: Double? {
        intervals.compactMap(\.maxHeartRateBPM).max()
    }
}
