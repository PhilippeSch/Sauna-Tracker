//
//  SessionModelTests.swift
//  Sauna TrackerTests
//
//  Derived values on SaunaSession, plus duration formatting.
//

import Testing
import Foundation
@testable import Sauna_Tracker

struct SaunaSessionTests {

    @Test func separatesSaunaRoundsFromRestIntervals() {
        let session = Fixture.session(start: Fixture.reference, rounds: 3, saunaSeconds: 600, restSeconds: 300)
        #expect(session.roundCount == 3)
        #expect(session.saunaRounds.count == 3)
        #expect(session.restIntervals.count == 2)
        #expect(session.totalSaunaDuration == 1800)
        #expect(session.totalRestDuration == 600)
    }

    @Test func averageRoundDurationIsZeroWithoutRounds() {
        let session = SaunaSession(
            startDate: Fixture.reference, endDate: Fixture.reference, intervals: [], metUsed: 1.75
        )
        #expect(session.averageRoundDuration == 0)
        #expect(session.maxHeartRateBPM == nil)
    }

    @Test func maxHeartRateIsThePeakAcrossAllIntervals() {
        let start = Fixture.reference
        let session = SaunaSession(
            startDate: start,
            endDate: start.addingTimeInterval(1200),
            intervals: [
                Fixture.interval(.sauna, start: start, seconds: 600, maxHR: 118),
                Fixture.interval(.rest, start: start.addingTimeInterval(600), seconds: 300, maxHR: 132),
                Fixture.interval(.sauna, start: start.addingTimeInterval(900), seconds: 300, maxHR: nil),
            ],
            metUsed: 1.75
        )
        #expect(session.maxHeartRateBPM == 132)
    }

    @Test func intervalDurationIsEndMinusStart() {
        let interval = Fixture.interval(.sauna, start: Fixture.reference, seconds: 754)
        #expect(interval.duration == 754)
    }

    @Test func phaseTimerBoundOutlastsARealisticPhase() {
        // The on-screen timer stops at the end of its range. A single sauna
        // or rest phase running past this bound would freeze on screen, which
        // is exactly what a one-hour bound used to do.
        #expect(SaunaPhase.maxDisplayedPhaseDuration >= 4 * 3600)
    }
}

struct DurationFormatterTests {

    @Test func subMinuteDurationsReportSecondsInsteadOfZeroMinutes() {
        #expect(DurationFormatter.abbreviated(0).contains("0"))
        #expect(DurationFormatter.abbreviated(45).contains("45"))
        #expect(DurationFormatter.abbreviated(45).contains("min") == false)
    }

    @Test func minutesAppearBelowAnHour() {
        let text = DurationFormatter.abbreviated(1800)
        #expect(text.contains("30"))
    }

    @Test func hoursAppearAboveAnHour() {
        let text = DurationFormatter.abbreviated(3600 + 720)
        #expect(text.contains("1"))
        #expect(text.contains("12"))
    }

    @Test func clockPadsMinutesAndSeconds() {
        #expect(DurationFormatter.clock(65) == "01:05")
    }

    @Test func clockAddsHoursOnlyWhenNeeded() {
        #expect(DurationFormatter.clock(3661) == "1:01:01")
        #expect(DurationFormatter.clock(3599) == "59:59")
    }

    @Test func negativeDurationsAreClampedRatherThanRendered() {
        #expect(DurationFormatter.clock(-30) == "00:00")
        #expect(DurationFormatter.abbreviated(-30).contains("0"))
    }
}

struct AppSettingsTests {

    @Test func defaultsMatchTheDocumentedValues() {
        let settings = AppSettings.default
        #expect(settings.metValue == 1.75)
        #expect(settings.maxRounds == 5)
        #expect(settings.hapticIntervalMinutes == 5)
        #expect(settings.bodyWeightOverrideKg == nil)
    }

    @Test func defaultMetSitsInsideTheAllowedRange() {
        #expect(AppSettings.metRange.contains(AppSettings.default.metValue))
        #expect(AppSettings.maxRoundsRange.contains(AppSettings.default.maxRounds))
        #expect(AppSettings.hapticIntervalRange.contains(AppSettings.default.hapticIntervalMinutes))
    }

    @Test func settingsSurviveEncodingForWatchConnectivity() throws {
        var settings = AppSettings.default
        settings.metValue = 1.9
        settings.maxRounds = 3
        settings.bodyWeightOverrideKg = 72.5

        let data = try JSONEncoder().encode(ConnectivityMessage.settingsChanged(settings))
        let decoded = try JSONDecoder().decode(ConnectivityMessage.self, from: data)

        guard case .settingsChanged(let roundTripped) = decoded else {
            Issue.record("expected a settingsChanged message")
            return
        }
        #expect(roundTripped == settings)
    }

    @Test func sessionSavedMessageRoundTrips() throws {
        let uuid = UUID()
        let data = try JSONEncoder().encode(ConnectivityMessage.sessionSaved(workoutUUID: uuid))
        let decoded = try JSONDecoder().decode(ConnectivityMessage.self, from: data)

        guard case .sessionSaved(let roundTripped) = decoded else {
            Issue.record("expected a sessionSaved message")
            return
        }
        #expect(roundTripped == uuid)
    }
}
