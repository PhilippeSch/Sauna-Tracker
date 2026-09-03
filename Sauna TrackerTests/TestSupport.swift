//
//  TestSupport.swift
//  Sauna TrackerTests
//
//  Builders and fakes shared by the suites.
//

import Foundation
@testable import Sauna_Tracker

enum Fixture {
    /// A fixed reference date so nothing depends on the wall clock.
    static let reference = Date(timeIntervalSince1970: 1_755_000_000) // 2025-08-12 12:40 UTC

    static func interval(
        _ phase: SaunaPhase,
        start: Date,
        seconds: TimeInterval,
        maxHR: Double? = nil
    ) -> SaunaInterval {
        SaunaInterval(
            phase: phase,
            startDate: start,
            endDate: start.addingTimeInterval(seconds),
            maxHeartRateBPM: maxHR
        )
    }

    /// A session of `rounds` sauna rounds separated by rest, each of the given length.
    static func session(
        start: Date,
        rounds: Int,
        saunaSeconds: TimeInterval = 600,
        restSeconds: TimeInterval = 300,
        maxHR: Double? = nil,
        kcal: Double? = nil,
        notes: String? = nil,
        met: Double = 1.75
    ) -> SaunaSession {
        var intervals: [SaunaInterval] = []
        var cursor = start
        for index in 0..<rounds {
            intervals.append(interval(.sauna, start: cursor, seconds: saunaSeconds, maxHR: maxHR))
            cursor = cursor.addingTimeInterval(saunaSeconds)
            // no trailing rest after the final round
            if index < rounds - 1 {
                intervals.append(interval(.rest, start: cursor, seconds: restSeconds))
                cursor = cursor.addingTimeInterval(restSeconds)
            }
        }
        return SaunaSession(
            startDate: start,
            endDate: cursor,
            intervals: intervals,
            notes: notes,
            metUsed: met,
            activeEnergyKcal: kcal
        )
    }

    /// UTC calendar so weekday/hour assertions don't depend on the test machine.
    static var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }
}

@MainActor
final class FakeRecorder: SessionRecording {
    var isRecording = true
    var onHeartRateUpdate: ((Double) -> Void)?
    var onSensorReadingsUpdate: ((RoundSensorReadings) -> Void)?

    private(set) var startCallCount = 0
    private(set) var finishCallCount = 0
    private(set) var discardCallCount = 0
    private(set) var lastFinishedSession: SaunaSession?
    private(set) var lastBodyWeightKg: Double?
    var stubbedUUID = UUID()
    var errorToThrow: Error?
    /// Stands in for the real recorder taking a moment to bring HealthKit up.
    var startDelay: Duration = .zero

    func startWorkoutSession(startDate: Date) async {
        startCallCount += 1
        if startDelay > .zero {
            try? await Task.sleep(for: startDelay)
        }
    }

    func finishAndSave(
        session: SaunaSession,
        maxRoundsConfigured: Int,
        bodyWeightKg: Double
    ) async throws -> UUID {
        finishCallCount += 1
        lastFinishedSession = session
        lastBodyWeightKg = bodyWeightKg
        if let errorToThrow { throw errorToThrow }
        return stubbedUUID
    }

    func discard() async {
        discardCallCount += 1
        isRecording = false
    }

    /// Drives the heart-rate callback the way the live builder would.
    func emitHeartRate(_ bpm: Double) {
        onHeartRateUpdate?(bpm)
    }
}

@MainActor
final class FakeHapticScheduler: HapticScheduling {
    private(set) var startCallCount = 0
    private(set) var stopCallCount = 0
    private(set) var lastInterval: Int?

    func start(intervalMinutes: Int) {
        startCallCount += 1
        lastInterval = intervalMinutes
    }

    func stop() {
        stopCallCount += 1
    }
}

@MainActor
enum StoreFactory {
    static func make(
        settings: AppSettings = .default,
        bodyWeightKg: Double? = 80
    ) -> (SessionStore, FakeRecorder, FakeHapticScheduler) {
        let recorder = FakeRecorder()
        let haptics = FakeHapticScheduler()
        let store = SessionStore(
            recorder: recorder,
            hapticScheduler: haptics,
            bodyWeightProvider: { override in override ?? bodyWeightKg }
        )
        store.settings = settings
        return (store, recorder, haptics)
    }
}
