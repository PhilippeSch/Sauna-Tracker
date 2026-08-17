//
//  SessionStore.swift
//  Sauna Tracker Watch App
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
    var maxConfiguredRounds: Int { settings.maxRounds }
    var canStartAnotherRound: Bool { roundCount < settings.maxRounds }
    var isActive: Bool { if case .active = stage { true } else { false } }

    private let recorder: HealthKitSessionRecorder
    private let connectivity: WatchConnectivityService
    private let hapticScheduler: HapticScheduler

    private var sessionID = UUID()
    private var sessionStartDate: Date?

    /// Weak reference to whichever instance is currently live, so the
    /// Action Button intent (a separate, short-lived execution) can reach
    /// the running session without us standing up app-wide DI for it.
    static weak var current: SessionStore?

    init(
        recorder: HealthKitSessionRecorder? = nil,
        connectivity: WatchConnectivityService = .shared,
        hapticScheduler: HapticScheduler? = nil
    ) {
        let recorder = recorder ?? HealthKitSessionRecorder()
        self.recorder = recorder
        self.connectivity = connectivity
        self.hapticScheduler = hapticScheduler ?? HapticScheduler()

        recorder.onHeartRateUpdate = { [weak self] bpm in
            self?.updateLiveHeartRate(bpm)
        }
        recorder.onSensorReadingsUpdate = { [weak self] readings in
            self?.latestSensorReadings = readings
        }

        Self.current = self
    }

    func startSession() async {
        guard case .idle = stage else { return }
        sessionID = UUID()
        sessionStartDate = .now
        intervals = []
        roundCount = 0
        stage = .active
        await recorder.startWorkoutSession(startDate: sessionStartDate!)
        beginPhase(.sauna)
    }

    private func beginPhase(_ phase: SaunaPhase) {
        currentPhase = phase
        phaseStartDate = .now
        maxHeartRateThisRound = 0
        latestSensorReadings = .empty
        if phase == .sauna { roundCount += 1 }
        hapticScheduler.start(intervalMinutes: settings.hapticIntervalMinutes)
    }

    /// Ends the current phase and starts the next one. Bound to the primary
    /// on-screen button and to the Action Button intent — both call the
    /// same code path.
    func advancePhase() {
        guard case .active = stage else { return }
        if currentPhase == .rest && !canStartAnotherRound { return }
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

    func endSession() async {
        guard case .active = stage, let start = sessionStartDate else { return }
        closeCurrentInterval()
        hapticScheduler.stop()

        let bodyWeightKg = await BodyWeightReader.resolvedBodyWeightKg(
            override: settings.bodyWeightOverrideKg
        ) ?? 75
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
                maxRoundsConfigured: settings.maxRounds,
                activeEnergyKcal: kcal
            )
            session.healthKitWorkoutUUID = workoutUUID
            connectivity.notifySessionSaved(workoutUUID: workoutUUID)
        } catch {
            lastErrorDescription = error.localizedDescription
        }
        stage = .summary(session)
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
