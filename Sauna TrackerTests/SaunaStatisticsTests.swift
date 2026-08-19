//
//  SaunaStatisticsTests.swift
//  Sauna TrackerTests
//

import Testing
import Foundation
@testable import Sauna_Tracker

struct SaunaStatisticsTests {
    private let calendar = Fixture.utcCalendar

    @Test func emptyInputProducesEmptyStats() {
        let stats = SaunaStatistics.compute(sessions: [], period: .all, now: Fixture.reference, calendar: calendar)
        #expect(stats.isEmpty)
        #expect(stats.sessionCount == 0)
        #expect(stats.totalSaunaTime == 0)
        #expect(stats.longestSessionDate == nil)
    }

    @Test func aggregatesCountsAndTotals() {
        let sessions = [
            Fixture.session(start: Fixture.reference, rounds: 3, saunaSeconds: 600, restSeconds: 300, kcal: 100),
            Fixture.session(start: Fixture.reference.addingTimeInterval(-3600), rounds: 2, saunaSeconds: 300, kcal: 40),
        ]
        let stats = SaunaStatistics.compute(sessions: sessions, period: .all, now: Fixture.reference, calendar: calendar)

        #expect(stats.sessionCount == 2)
        #expect(stats.totalRounds == 5)
        #expect(stats.totalSaunaTime == 3 * 600 + 2 * 300)
        #expect(stats.totalRestTime == 2 * 300 + 1 * 300)
        #expect(stats.totalCalories == 140)
    }

    @Test func averagesDivideByTheRightDenominator() {
        let sessions = [
            Fixture.session(start: Fixture.reference, rounds: 2, saunaSeconds: 600, kcal: 100),
            Fixture.session(start: Fixture.reference.addingTimeInterval(-7200), rounds: 2, saunaSeconds: 300, kcal: 50),
        ]
        let stats = SaunaStatistics.compute(sessions: sessions, period: .all, now: Fixture.reference, calendar: calendar)

        // 4 rounds totalling 1800s
        #expect(stats.averageRoundDuration == 450)
        // 2 sessions totalling 1800s
        #expect(stats.averageSessionSaunaTime == 900)
        #expect(stats.averageCaloriesPerSession == 75)
    }

    @Test func missingCaloriesCountAsZeroRatherThanBreakingTheTotal() {
        let sessions = [
            Fixture.session(start: Fixture.reference, rounds: 1, kcal: 60),
            Fixture.session(start: Fixture.reference.addingTimeInterval(-600), rounds: 1, kcal: nil),
        ]
        let stats = SaunaStatistics.compute(sessions: sessions, period: .all, now: Fixture.reference, calendar: calendar)
        #expect(stats.totalCalories == 60)
        #expect(stats.averageCaloriesPerSession == 30)
    }

    @Test func heartRateStatsIgnoreSessionsWithoutReadings() {
        let sessions = [
            Fixture.session(start: Fixture.reference, rounds: 1, maxHR: 120),
            Fixture.session(start: Fixture.reference.addingTimeInterval(-600), rounds: 1, maxHR: 150),
            Fixture.session(start: Fixture.reference.addingTimeInterval(-1200), rounds: 1, maxHR: nil),
        ]
        let stats = SaunaStatistics.compute(sessions: sessions, period: .all, now: Fixture.reference, calendar: calendar)

        #expect(stats.peakHeartRate == 150)
        #expect(stats.averageMaxHeartRate == 135, "averages over the two sessions that had readings")
    }

    @Test func heartRateStatsAreNilWhenNothingWasRecorded() {
        let sessions = [Fixture.session(start: Fixture.reference, rounds: 1, maxHR: nil)]
        let stats = SaunaStatistics.compute(sessions: sessions, period: .all, now: Fixture.reference, calendar: calendar)
        #expect(stats.averageMaxHeartRate == nil)
        #expect(stats.peakHeartRate == nil)
    }

    @Test func longestSessionIsMeasuredBySaunaTimeNotWallClock() {
        let shortSaunaLongRests = Fixture.session(
            start: Fixture.reference.addingTimeInterval(-86_400), rounds: 3, saunaSeconds: 120, restSeconds: 3600
        )
        let longSauna = Fixture.session(start: Fixture.reference, rounds: 1, saunaSeconds: 1800)
        let stats = SaunaStatistics.compute(
            sessions: [shortSaunaLongRests, longSauna], period: .all, now: Fixture.reference, calendar: calendar
        )

        #expect(stats.longestSessionSaunaTime == 1800)
        #expect(stats.longestSessionDate == longSauna.startDate)
    }

    @Test func periodFilteringExcludesOlderSessions() {
        let now = Fixture.reference
        let today = Fixture.session(start: now.addingTimeInterval(-600), rounds: 1)
        let lastMonth = Fixture.session(start: now.addingTimeInterval(-40 * 86_400), rounds: 1)

        let all = SaunaStatistics.compute(sessions: [today, lastMonth], period: .all, now: now, calendar: calendar)
        #expect(all.sessionCount == 2)

        let day = SaunaStatistics.compute(sessions: [today, lastMonth], period: .day, now: now, calendar: calendar)
        #expect(day.sessionCount == 1)

        let year = SaunaStatistics.compute(sessions: [today, lastMonth], period: .year, now: now, calendar: calendar)
        #expect(year.sessionCount == 2, "both fall in the same calendar year")
    }

    @Test func mostFrequentWeekdayAndHourPickTheModalValue() {
        // Three sessions at 18:00 on the same weekday, one at 07:00 a day later.
        let base = calendar.date(from: DateComponents(year: 2025, month: 8, day: 4, hour: 18))!
        let sessions = [
            Fixture.session(start: base, rounds: 1),
            Fixture.session(start: calendar.date(byAdding: .day, value: 7, to: base)!, rounds: 1),
            Fixture.session(start: calendar.date(byAdding: .day, value: 14, to: base)!, rounds: 1),
            Fixture.session(start: calendar.date(from: DateComponents(year: 2025, month: 8, day: 5, hour: 7))!, rounds: 1),
        ]
        let now = calendar.date(from: DateComponents(year: 2025, month: 8, day: 20))!
        let stats = SaunaStatistics.compute(sessions: sessions, period: .all, now: now, calendar: calendar)

        #expect(stats.mostFrequentWeekday == calendar.component(.weekday, from: base))
        #expect(stats.mostFrequentHour == 18)
    }

    @Test func tiedModesResolveDeterministicallyToTheSmallestValue() {
        let day1 = calendar.date(from: DateComponents(year: 2025, month: 8, day: 4, hour: 8))!
        let day2 = calendar.date(from: DateComponents(year: 2025, month: 8, day: 5, hour: 20))!
        let sessions = [Fixture.session(start: day1, rounds: 1), Fixture.session(start: day2, rounds: 1)]
        let now = calendar.date(from: DateComponents(year: 2025, month: 8, day: 20))!

        let first = SaunaStatistics.compute(sessions: sessions, period: .all, now: now, calendar: calendar)
        let second = SaunaStatistics.compute(sessions: sessions.reversed(), period: .all, now: now, calendar: calendar)

        #expect(first.mostFrequentHour == 8)
        #expect(first == second, "input order must not change the result")
    }

    @Test func periodStartsAreNilOnlyForAll() {
        #expect(StatsPeriod.all.startDate(now: Fixture.reference, calendar: calendar) == nil)
        for period in [StatsPeriod.day, .week, .month, .year] {
            #expect(period.startDate(now: Fixture.reference, calendar: calendar) != nil)
        }
    }
}
