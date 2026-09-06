//
//  WorkoutHistoryStore.swift
//  Sauna Companion
//
//  Reads past sauna sessions back out of HealthKit. We only ever query
//  `.other` workouts that carry our metadata key, so other "Other" workouts
//  the user may have logged elsewhere are never mistaken for sauna sessions.
//

import HealthKit

enum WorkoutHistoryStore {
    static func fetchAllSessions() async -> [SaunaSession] {
        guard let healthStore = HealthKitAuthorization.healthStore else { return [] }

        let workoutPredicate = HKQuery.predicateForWorkouts(with: .other)
        let metadataPredicate = HKQuery.predicateForObjects(
            withMetadataKey: SessionMetadataPayload.metadataKey
        )
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            workoutPredicate, metadataPredicate,
        ])
        let sort = [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]

        let workouts: [HKWorkout] = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HealthKitTypes.workoutType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: sort
            ) { _, samples, _ in
                continuation.resume(returning: (samples as? [HKWorkout]) ?? [])
            }
            healthStore.execute(query)
        }

        return workouts.compactMap(session(from:))
    }

    /// Removes the session's workout from Health. HealthKit deletes the
    /// samples it owns along with it, so the entry disappears everywhere.
    static func delete(_ session: SaunaSession) async throws {
        guard let healthStore = HealthKitAuthorization.healthStore else { return }
        guard let uuid = session.healthKitWorkoutUUID else { return }

        let workouts: [HKWorkout] = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HealthKitTypes.workoutType,
                predicate: HKQuery.predicateForObject(with: uuid),
                limit: 1,
                sortDescriptors: nil
            ) { _, samples, _ in
                continuation.resume(returning: (samples as? [HKWorkout]) ?? [])
            }
            healthStore.execute(query)
        }

        guard let workout = workouts.first else { return }
        try await healthStore.delete(workout)
    }

    private static func session(from workout: HKWorkout) -> SaunaSession? {
        guard
            let jsonString = workout.metadata?[SessionMetadataPayload.metadataKey] as? String,
            let payload = SessionMetadataCoding.decode(jsonString)
        else { return nil }

        let kcal = workout.statistics(for: HealthKitTypes.activeEnergy)?
            .sumQuantity()?.doubleValue(for: .kilocalorie())

        // The workout UUID is the session's identity, not a fresh one per
        // fetch: SwiftUI diffs the history list by it, and random ids made
        // every reload look like a full replacement — the rows visibly jumped.
        return SaunaSession(
            id: workout.uuid,
            startDate: workout.startDate,
            endDate: workout.endDate,
            intervals: payload.intervals,
            notes: payload.notes,
            metUsed: payload.metUsed,
            activeEnergyKcal: kcal,
            healthKitWorkoutUUID: workout.uuid
        )
    }
}
