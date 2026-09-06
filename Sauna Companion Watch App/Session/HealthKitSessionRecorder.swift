//
//  HealthKitSessionRecorder.swift
//  Sauna Companion Watch App
//
//  Wraps HKWorkoutSession + HKLiveWorkoutBuilder: starts a live `.other`
//  indoor workout, streams heart rate up to SessionStore, and on finish
//  writes the MET-based active energy samples + our session metadata blob,
//  then saves.
//
//  Ordering matters and is easy to get wrong: endCollection(withEnd:)
//  *deactivates* the builder, so every sample and all metadata must be added
//  BEFORE it. The sequence below is: add samples -> add metadata ->
//  session.end() -> wait for .ended -> endCollection -> finishWorkout.
//

import Foundation
import HealthKit
import os

@MainActor
final class HealthKitSessionRecorder: NSObject, SessionRecording {
    enum RecordingError: LocalizedError {
        case notStarted
        case saveFailed

        var errorDescription: String? {
            switch self {
            case .notStarted: String(localized: "error.notRecorded", defaultValue: "Not saved to Health")
            case .saveFailed: String(localized: "error.saveFailed", defaultValue: "Could not save to Health")
            }
        }
    }

    private static let log = Logger(subsystem: "Scheuber.Sauna-Tracker", category: "HealthKit")

    var onHeartRateUpdate: ((Double) -> Void)?

    /// True once a live workout session is actually running, so the UI can
    /// tell the user their session is not being recorded to Health.
    private(set) var isRecording = false

    private var workoutSession: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var endStateContinuation: CheckedContinuation<Void, Never>?

    func startWorkoutSession(startDate: Date) async {
        guard let healthStore = HealthKitAuthorization.healthStore else {
            Self.log.error("No health store available — session will not be recorded")
            return
        }

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .other
        configuration.locationType = .indoor

        do {
            let session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            let builder = session.associatedWorkoutBuilder()

            let dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)
            // We compute energy ourselves from the MET model, so the sensor
            // driven energy the data source would otherwise collect has to be
            // switched off — otherwise the workout ends up with both.
            dataSource.disableCollection(for: HKQuantityType(.activeEnergyBurned))
            dataSource.disableCollection(for: HKQuantityType(.basalEnergyBurned))
            builder.dataSource = dataSource

            session.delegate = self
            builder.delegate = self

            workoutSession = session
            self.builder = builder

            session.startActivity(with: startDate)
            try await beginCollection(builder, start: startDate)
            isRecording = true
            Self.log.info("Workout session started, collecting: \(dataSource.typesToCollect.map(\.identifier).joined(separator: ", "))")

            // The Action button only runs a "next action" while a workout
            // session is live, and it has to be donated from wherever the
            // session actually starts — here — so that a session started with
            // the on-screen button arms the button just the same.
            await ActionButton.armPhaseToggle()
        } catch {
            isRecording = false
            workoutSession = nil
            builder = nil
            Self.log.error("Failed to start workout session: \(error.localizedDescription)")
        }
    }

    /// Writes the MET-based energy samples and session metadata, ends the
    /// workout and saves it. Returns the resulting workout UUID.
    func finishAndSave(
        session: SaunaSession,
        bodyWeightKg: Double
    ) async throws -> UUID {
        guard let workoutSession, let builder else {
            throw RecordingError.notStarted
        }

        // Placed after the guard so the .notStarted path leaves the (already
        // cleared) state alone. Anything below can throw, and a session left
        // behind would keep running: watchOS allows only one live workout, so
        // the next start would fail while the first drained the battery.
        defer {
            self.workoutSession = nil
            self.builder = nil
            isRecording = false
        }

        // 1. Samples first — the builder must still be active.
        let energySamples = energySamples(for: session, bodyWeightKg: bodyWeightKg, builderStart: builder.startDate)
        if !energySamples.isEmpty {
            do {
                try await builder.addSamples(energySamples)
                Self.log.info("Added \(energySamples.count) active energy sample(s)")
            } catch {
                Self.log.error("Failed to add energy samples: \(error.localizedDescription)")
            }
        }

        // 2. Metadata, still before endCollection.
        let payload = SessionMetadataPayload(session: session)
        if let encoded = SessionMetadataCoding.encode(payload) {
            do {
                try await builder.addMetadata([SessionMetadataPayload.metadataKey: encoded])
            } catch {
                Self.log.error("Failed to add metadata: \(error.localizedDescription)")
            }
        }

        // 3. End the session and wait for it to actually reach .ended before
        //    deactivating the builder.
        workoutSession.end()
        await waitForEndedState()

        try await endCollection(builder, end: session.endDate)

        guard let workout = try await builder.finishWorkout() else {
            throw RecordingError.saveFailed
        }

        let savedKcal = workout.statistics(for: HealthKitTypes.activeEnergy)?
            .sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
        Self.log.info("Saved workout \(workout.uuid.uuidString), energy \(savedKcal, format: .fixed(precision: 1)) kcal")

        return workout.uuid
    }

    /// Ends the live workout and throws the recording away. Nothing is
    /// written to Health — used when the session was a false start and the
    /// user asks for it to be deleted rather than saved.
    func discard() async {
        guard let session = workoutSession, let liveBuilder = builder else {
            isRecording = false
            return
        }

        session.end()
        await waitForEndedState()
        liveBuilder.discardWorkout()

        workoutSession = nil
        builder = nil
        isRecording = false
        Self.log.info("Workout discarded — nothing written to Health")
    }

    /// One active-energy sample per Sauna round, so rest phases contribute
    /// nothing and the energy lines up with the time actually spent in heat.
    private func energySamples(
        for session: SaunaSession,
        bodyWeightKg: Double,
        builderStart: Date?
    ) -> [HKQuantitySample] {
        // HealthKit rejects samples that start at or before the builder's own
        // start date, so nudge the first one just past it.
        let earliestAllowed = (builderStart ?? session.startDate).addingTimeInterval(1)

        return session.saunaRounds.compactMap { round in
            let start = max(round.startDate, earliestAllowed)
            guard round.endDate > start else { return nil }

            let kcal = CalorieCalculator.activeEnergyKcal(
                saunaIntervals: [round],
                metValue: session.metUsed,
                bodyWeightKg: bodyWeightKg
            )
            guard kcal > 0 else { return nil }

            return HKQuantitySample(
                type: HealthKitTypes.activeEnergy,
                quantity: HKQuantity(unit: .kilocalorie(), doubleValue: kcal),
                start: start,
                end: round.endDate
            )
        }
    }

    private func waitForEndedState(timeout: TimeInterval = 5) async {
        guard let workoutSession, workoutSession.state != .ended else { return }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            endStateContinuation = continuation
            // The task inherits this type's main-actor isolation, so the
            // resume call is already on the right actor and needs no await.
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(timeout))
                self?.resumeEndStateWait()
            }
        }
    }

    private func resumeEndStateWait() {
        endStateContinuation?.resume()
        endStateContinuation = nil
    }

    // HKLiveWorkoutBuilder's begin/end collection only ship completion-handler
    // overloads, so bridge them to async/await.
    private func beginCollection(_ builder: HKLiveWorkoutBuilder, start: Date) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            builder.beginCollection(withStart: start) { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    private func endCollection(_ builder: HKLiveWorkoutBuilder, end: Date) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            builder.endCollection(withEnd: end) { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }
}

extension HealthKitSessionRecorder: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        guard toState == .ended else { return }
        Task { @MainActor [weak self] in
            self?.resumeEndStateWait()
        }
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        Task { @MainActor [weak self] in
            Self.log.error("Workout session failed: \(error.localizedDescription)")
            self?.isRecording = false
            self?.resumeEndStateWait()
        }
    }
}

extension HealthKitSessionRecorder: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilder(
        _ workoutBuilder: HKLiveWorkoutBuilder,
        didCollectDataOf collectedTypes: Set<HKSampleType>
    ) {
        Task { @MainActor in
            for type in collectedTypes {
                guard
                    let quantityType = type as? HKQuantityType,
                    let statistics = workoutBuilder.statistics(for: quantityType)
                else { continue }
                handle(statistics: statistics, for: quantityType)
            }
        }
    }

    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    private func handle(statistics: HKStatistics, for quantityType: HKQuantityType) {
        switch quantityType {
        case HealthKitTypes.heartRate:
            guard let bpm = statistics.mostRecentQuantity()?
                .doubleValue(for: .count().unitDivided(by: .minute()))
            else { return }
            onHeartRateUpdate?(bpm)

        default:
            break
        }
    }
}
