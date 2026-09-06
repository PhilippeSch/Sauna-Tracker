//
//  SessionStore.swift
//  Sauna Companion Watch App
//
//  Drives the whole session flow: start -> sauna round -> rest -> repeat ->
//  end -> save. This is the single source of truth ActiveSessionView (and
//  the Action Button intent) read from and act on.
//

import Foundation
import Observation

@MainActor
@Observable
final class SessionStore {
    enum Stage {
        case idle
        case active
        case saving
        case summary(SaunaSession)
    }

    private(set) var stage: Stage = .idle
    private(set) var currentPhase: SaunaPhase = .sauna
    private(set) var phaseStartDate: Date = .now
    private(set) var currentHeartRate: Double?
    private(set) var maxHeartRateThisRound: Double = 0
    private(set) var latestSensorReadings: RoundSensorReadings = .empty
    private(set) var intervals: [SaunaInterval] = []
    private(set) var roundCount: Int = 0
    private(set) var lastErrorDescription: String?

    var settings: AppSettings = .default
    var isActive: Bool { if case .active = stage { true } else { false } }

    /// False when HealthKit refused to start a live workout — the session
    /// still runs locally, but nothing will land in Health, and the UI says so.
    var isRecordingToHealth: Bool { recorder.isRecording }

    /// Total sauna time so far, including the round currently running.
    var totalSaunaDurationSoFar: TimeInterval {
        let closed = intervals.filter { $0.phase == .sauna }.reduce(0) { $0 + $1.duration }
        let live = currentPhase == .sauna ? Date.now.timeIntervalSince(phaseStartDate) : 0
        return closed + live
    }

    /// Wall-clock length of the whole session so far, sauna and rest together.
    var totalSessionDurationSoFar: TimeInterval {
        guard let sessionStartDate else { return 0 }
        return Date.now.timeIntervalSince(sessionStartDate)
    }

    private let recorder: SessionRecording
    private let connectivity: WatchConnectivityService
    private let hapticScheduler: HapticScheduling
    private let bodyWeightProvider: BodyWeightProviding

    private var sessionID = UUID()
    private var sessionStartDate: Date?

    /// Weak reference to whichever instance is currently live, so the Action
    /// button intents (a separate, short-lived execution) can reach the
    /// running session without standing up app-wide DI for it.
    ///
    /// Registered explicitly by whoever owns the live store, never from
    /// `init`: SwiftUI re-evaluates a `@State` default-value expression on
    /// every view-struct initialisation and keeps only the first instance, so
    /// an `init` side effect here pointed this at a discarded store — and,
    /// being weak, it then went nil. App Intents found nothing to act on.
    static weak var current: SessionStore?

    /// Marks this instance as the one App Intents should drive.
    func makeCurrent() {
        Self.current = self
    }

    // The shared singletons are resolved inside the body rather than as
    // default arguments: those are evaluated in a nonisolated context, where
    // touching a main-actor property is an error under the Swift 6 language
    // mode.
    init(
        recorder: SessionRecording,
        connectivity: WatchConnectivityService? = nil,
        hapticScheduler: HapticScheduling,
        bodyWeightProvider: BodyWeightProviding? = nil
    ) {
        self.recorder = recorder
        self.connectivity = connectivity ?? .shared
        self.hapticScheduler = hapticScheduler
        self.bodyWeightProvider = bodyWeightProvider ?? DefaultBodyWeightProvider.live

        recorder.onHeartRateUpdate = { [weak self] bpm in
            self?.updateLiveHeartRate(bpm)
        }
        recorder.onSensorReadingsUpdate = { [weak self] readings in
            self?.latestSensorReadings = readings
        }
    }

    func startSession() async {
        guard case .idle = stage else { return }
        let start = Date.now
        sessionID = UUID()
        sessionStartDate = start
        intervals = []
        roundCount = 0
        lastErrorDescription = nil
        stage = .active
        await recorder.startWorkoutSession(startDate: start)
        // Starts at `start`, not "now": bringing up the HealthKit session
        // takes about a second, and the first round has to line up with the
        // session it belongs to rather than trail it.
        beginPhase(.sauna, at: start)
    }

    private func beginPhase(_ phase: SaunaPhase, at date: Date = .now) {
        currentPhase = phase
        phaseStartDate = date
        maxHeartRateThisRound = 0
        latestSensorReadings = .empty
        if phase == .sauna { roundCount += 1 }
        // The interval reminder is about time spent in the heat, so it runs
        // during sauna rounds only — a tap in the middle of a rest phase is
        // just noise. The else branch also cancels whatever was still running.
        if phase == .sauna, settings.hapticsEnabled {
            hapticScheduler.start(intervalMinutes: settings.hapticIntervalMinutes)
        } else {
            hapticScheduler.stop()
        }
    }

    /// Ends the current phase and starts the next one. Bound to the primary
    /// on-screen button and to the Action Button intent — both call the
    /// same code path.
    ///
    /// There is no cap on the number of rounds: a session runs until it is
    /// ended explicitly.
    func advancePhase() {
        guard case .active = stage else { return }
        closeCurrentInterval()
        beginPhase(currentPhase == .sauna ? .rest : .sauna)
    }

    private func closeCurrentInterval() {
        intervals.append(
            SaunaInterval(
                phase: currentPhase,
                startDate: phaseStartDate,
                endDate: .now,
                maxHeartRateBPM: maxHeartRateThisRound > 0 ? maxHeartRateThisRound : nil,
                sensorReadings: latestSensorReadings
            )
        )
        hapticScheduler.stop()
    }

    func updateLiveHeartRate(_ bpm: Double) {
        currentHeartRate = bpm
        maxHeartRateThisRound = max(maxHeartRateThisRound, bpm)
    }

    /// Ends the whole session from any phase and at any round, then saves.
    func endSession() async {
        guard case .active = stage, let start = sessionStartDate else { return }
        closeCurrentInterval()
        hapticScheduler.stop()
        stage = .saving

        let bodyWeightKg = await bodyWeightProvider(settings.bodyWeightOverrideKg)
            ?? AppSettings.fallbackBodyWeightKg

        let kcal = CalorieCalculator.activeEnergyKcal(
            saunaIntervals: intervals,
            metValue: settings.metValue,
            bodyWeightKg: bodyWeightKg
        )

        var session = SaunaSession(
            id: sessionID,
            startDate: start,
            endDate: .now,
            intervals: intervals,
            metUsed: settings.metValue,
            activeEnergyKcal: kcal
        )

        do {
            let workoutUUID = try await recorder.finishAndSave(
                session: session,
                bodyWeightKg: bodyWeightKg
            )
            session.healthKitWorkoutUUID = workoutUUID
            connectivity.notifySessionSaved(workoutUUID: workoutUUID)
        } catch {
            lastErrorDescription = error.localizedDescription
        }
        stage = .summary(session)
    }

    /// Ends the session and throws it away: the live workout is discarded, so
    /// nothing lands in Health and there is no summary to acknowledge. The UI
    /// returns to idle straight away — the discard itself is just cleanup.
    func discardSession() async {
        guard case .active = stage else { return }
        hapticScheduler.stop()
        reset()
        sessionStartDate = nil
        await recorder.discard()
    }

    func reset() {
        stage = .idle
        currentPhase = .sauna
        currentHeartRate = nil
        maxHeartRateThisRound = 0
        latestSensorReadings = .empty
        intervals = []
        roundCount = 0
        lastErrorDescription = nil
    }

    func applySettings(_ newSettings: AppSettings) {
        settings = newSettings
    }
}
