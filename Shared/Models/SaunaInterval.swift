//
//  SaunaInterval.swift
//  Sauna Companion
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

    init(
        id: UUID = UUID(),
        phase: SaunaPhase,
        startDate: Date,
        endDate: Date,
        maxHeartRateBPM: Double? = nil
    ) {
        self.id = id
        self.phase = phase
        self.startDate = startDate
        self.endDate = endDate
        self.maxHeartRateBPM = maxHeartRateBPM
    }

    var duration: TimeInterval { endDate.timeIntervalSince(startDate) }
}
