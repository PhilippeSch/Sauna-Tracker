//
//  SessionMetadataCodingTests.swift
//  Sauna CompanionTests
//

import Testing
import Foundation
@testable import Sauna_Companion

struct SessionMetadataCodingTests {
    @Test func roundTripsIntervalsAndNotes() {
        let start = Date()
        let interval = SaunaInterval(
            phase: .sauna,
            startDate: start,
            endDate: start.addingTimeInterval(600),
            maxHeartRateBPM: 142,
            sensorReadings: RoundSensorReadings(hrv: 45, respiratoryRate: 16, spo2: 0.98, wristTemperatureC: 33.2)
        )
        let session = SaunaSession(
            startDate: start,
            endDate: start.addingTimeInterval(1800),
            intervals: [interval],
            notes: "Finnish sauna 90°C",
            metUsed: 1.75
        )
        let payload = SessionMetadataPayload(session: session)

        let encoded = SessionMetadataCoding.encode(payload)
        #expect(encoded != nil)

        let decoded = encoded.flatMap(SessionMetadataCoding.decode)
        #expect(decoded?.notes == "Finnish sauna 90°C")
        #expect(decoded?.intervals.count == 1)
        #expect(decoded?.intervals.first?.maxHeartRateBPM == 142)
        #expect(decoded?.intervals.first?.sensorReadings.hrv == 45)
        #expect(decoded?.metUsed == 1.75)
    }

    @Test func decodeFailsGracefullyOnGarbage() {
        #expect(SessionMetadataCoding.decode("not json") == nil)
    }
}
