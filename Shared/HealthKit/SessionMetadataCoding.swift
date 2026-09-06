//
//  SessionMetadataCoding.swift
//  Sauna Companion
//
//  The lean payload we round-trip through HKWorkout.metadata. Raw heart
//  rate samples are NOT included here — they're saved as proper
//  HKQuantitySamples tied to the workout and re-queried when needed.
//

import Foundation

struct SessionMetadataPayload: Codable {
    static let metadataKey = "com.philippescheuber.SaunaTracker.session"

    var schemaVersion: Int = 1
    var metUsed: Double
    var intervals: [SaunaInterval]
    var notes: String?

    init(session: SaunaSession) {
        self.metUsed = session.metUsed
        self.intervals = session.intervals
        self.notes = session.notes
    }
}

enum SessionMetadataCoding {
    static func encode(_ payload: SessionMetadataPayload) -> String? {
        guard let data = try? JSONEncoder().encode(payload) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func decode(_ jsonString: String) -> SessionMetadataPayload? {
        guard let data = jsonString.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(SessionMetadataPayload.self, from: data)
    }
}
