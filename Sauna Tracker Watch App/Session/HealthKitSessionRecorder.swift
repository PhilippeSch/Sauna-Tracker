//
//  HealthKitSessionRecorder.swift
//  Sauna Tracker Watch App
//
//  Wraps HKWorkoutSession + HKLiveWorkoutBuilder: starts a live `.other`
//  indoor workout, streams heart rate (and whichever optional sensors the
//  system happens to surface) up to SessionStore, and on finish writes the
//  active energy sample + our session metadata blob and saves the workout.
//

import Foundation
import HealthKit

@MainActor
final class HealthKitSessionRecorder: NSObject {
    enum RecordingError: Error {
        case notStarted
        case saveFailed
    }

    var onHeartRateUpdate: ((Double) -> Void)?
    var onSensorReadingsUpdate: ((RoundSensorReadings) -> Void)?

    private var workoutSession: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var latestReadings = RoundSensorReadings.empty

    func startWorkoutSession(startDate: Date) async {
        guard let healthStore = HealthKitAuthorization.healthStore else { return }

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .other
        configuration.locationType = .indoor

        do {
            let session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            let builder = session.associatedWorkoutBuilder()
            builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)
            session.delegate = self
            builder.delegate = self

            workoutSession = session
            self.builder = builder

            session.startActivity(with: startDate)
            try await beginCollection(builder, start: startDate)
        } catch {
            // Best-effort: the on-screen timers/state machine keep working
            // locally even if HealthKit can't start (e.g. Simulator, no auth).
        }
    }

    /// Ends the workout, writes the computed active-energy sample and the
    /// session metadata blob, and saves. Returns the resulting workout UUID.
    func finishAndSave(
        session: SaunaSession,
        maxRoundsConfigured: Int,
        activeEnergyKcal: Double
    ) async throws -> UUID {
        guard let workoutSession, let builder else {
            throw RecordingError.notStarted
        }

        workoutSession.end()
        try await endCollection(builder, end: session.endDate)

        if activeEnergyKcal > 0 {
            let quantity = HKQuantity(unit: .kilocalorie(), doubleValue: activeEnergyKcal)
            let sample = HKQuantitySample(
                type: HealthKitTypes.activeEnergy,
                quantity: quantity,
                start: session.startDate,
                end: session.endDate
            )
            try? await builder.addSamples([sample])
        }

        let payload = SessionMetadataPayload(session: session, maxRoundsConfigured: maxRoundsConfigured)
        if let encoded = SessionMetadataCoding.encode(payload) {
            try? await builder.addMetadata([SessionMetadataPayload.metadataKey: encoded])
        }

        guard let workout = try await builder.finishWorkout() else {
            throw RecordingError.saveFailed
        }

        self.workoutSession = nil
        self.builder = nil
        return workout.uuid
    }

    // HKLiveWorkoutBuilder's begin/end collection only ship completion-handler
    // overloads (unlike addSamples/addMetadata/finishWorkout, which have
    // async variants) — bridge them so the rest of this type can stay async/await.
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
    ) {}

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {}
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

        case HealthKitTypes.hrv:
            latestReadings.hrv = statistics.mostRecentQuantity()?
                .doubleValue(for: .secondUnit(with: .milli))
            onSensorReadingsUpdate?(latestReadings)

        case HealthKitTypes.respiratoryRate:
            latestReadings.respiratoryRate = statistics.mostRecentQuantity()?
                .doubleValue(for: .count().unitDivided(by: .minute()))
            onSensorReadingsUpdate?(latestReadings)

        case HealthKitTypes.oxygenSaturation:
            latestReadings.spo2 = statistics.mostRecentQuantity()?.doubleValue(for: .percent())
            onSensorReadingsUpdate?(latestReadings)

        case HealthKitTypes.wristTemperature:
            latestReadings.wristTemperatureC = statistics.mostRecentQuantity()?
                .doubleValue(for: .degreeCelsius())
            onSensorReadingsUpdate?(latestReadings)

        default:
            break
        }
    }
}
