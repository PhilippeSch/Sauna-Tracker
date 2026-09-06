//
//  SaunaStatistics.swift
//  Sauna Companion
//
//  Pure aggregation over a list of sessions. Deliberately free of HealthKit
//  and SwiftUI, and takes `now`/`calendar` as parameters rather than reading
//  the clock, so the numbers on screen are reproducible in tests.
//

import Foundation

enum StatsPeriod: String, CaseIterable, Identifiable, Sendable {
    case day, week, month, year, all

    var id: String { rawValue }

    var title: String {
        switch self {
        case .day: String(localized: "period.day", defaultValue: "Day")
        case .week: String(localized: "period.week", defaultValue: "Week")
        case .month: String(localized: "period.month", defaultValue: "Month")
        case .year: String(localized: "period.year", defaultValue: "Year")
        case .all: String(localized: "period.all", defaultValue: "All")
        }
    }

    /// Start of the current period, or nil for `.all`.
    func startDate(now: Date, calendar: Calendar) -> Date? {
        let component: Calendar.Component
        switch self {
        case .day: component = .day
        case .week: component = .weekOfYear
        case .month: component = .month
        case .year: component = .year
        case .all: return nil
        }
        return calendar.dateInterval(of: component, for: now)?.start
    }

    func contains(_ date: Date, now: Date, calendar: Calendar) -> Bool {
        guard let start = startDate(now: now, calendar: calendar) else { return true }
        return date >= start
    }
}

struct SaunaStatistics: Equatable, Sendable {
    var sessionCount: Int = 0
    var totalRounds: Int = 0
    var totalSaunaTime: TimeInterval = 0
    var totalRestTime: TimeInterval = 0
    var totalCalories: Double = 0
    var averageRoundDuration: TimeInterval = 0
    var averageSessionSaunaTime: TimeInterval = 0
    var averageCaloriesPerSession: Double = 0
    var averageMaxHeartRate: Double?
    var peakHeartRate: Double?
    var longestSessionSaunaTime: TimeInterval = 0
    var longestSessionDate: Date?
    /// Calendar weekday (1 = Sunday) that appears most often, nil if no data.
    var mostFrequentWeekday: Int?
    /// Hour of day (0-23) that appears most often, nil if no data.
    var mostFrequentHour: Int?

    var isEmpty: Bool { sessionCount == 0 }

    static func compute(
        sessions: [SaunaSession],
        period: StatsPeriod = .all,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> SaunaStatistics {
        let scoped = sessions.filter { period.contains($0.startDate, now: now, calendar: calendar) }
        guard !scoped.isEmpty else { return SaunaStatistics() }

        var stats = SaunaStatistics()
        stats.sessionCount = scoped.count
        stats.totalRounds = scoped.reduce(0) { $0 + $1.roundCount }
        stats.totalSaunaTime = scoped.reduce(0) { $0 + $1.totalSaunaDuration }
        stats.totalRestTime = scoped.reduce(0) { $0 + $1.totalRestDuration }
        stats.totalCalories = scoped.reduce(0) { $0 + ($1.activeEnergyKcal ?? 0) }

        stats.averageRoundDuration = stats.totalRounds > 0
            ? stats.totalSaunaTime / Double(stats.totalRounds)
            : 0
        stats.averageSessionSaunaTime = stats.totalSaunaTime / Double(scoped.count)
        stats.averageCaloriesPerSession = stats.totalCalories / Double(scoped.count)

        let maxHeartRates = scoped.compactMap(\.maxHeartRateBPM)
        if !maxHeartRates.isEmpty {
            stats.averageMaxHeartRate = maxHeartRates.reduce(0, +) / Double(maxHeartRates.count)
            stats.peakHeartRate = maxHeartRates.max()
        }

        // Ties broken by start date so the answer never depends on the order
        // HealthKit happened to return the workouts in.
        let longest = scoped.max { lhs, rhs in
            lhs.totalSaunaDuration == rhs.totalSaunaDuration
                ? lhs.startDate < rhs.startDate
                : lhs.totalSaunaDuration < rhs.totalSaunaDuration
        }
        if let longest {
            stats.longestSessionSaunaTime = longest.totalSaunaDuration
            stats.longestSessionDate = longest.startDate
        }

        stats.mostFrequentWeekday = mode(
            scoped.map { calendar.component(.weekday, from: $0.startDate) }
        )
        stats.mostFrequentHour = mode(
            scoped.map { calendar.component(.hour, from: $0.startDate) }
        )
        return stats
    }

    /// Most common value; ties resolve to the smallest value so results are
    /// stable rather than dependent on dictionary ordering.
    private static func mode(_ values: [Int]) -> Int? {
        guard !values.isEmpty else { return nil }
        let counts = values.reduce(into: [Int: Int]()) { $0[$1, default: 0] += 1 }
        guard let best = counts.values.max() else { return nil }
        return counts.filter { $0.value == best }.keys.min()
    }
}
