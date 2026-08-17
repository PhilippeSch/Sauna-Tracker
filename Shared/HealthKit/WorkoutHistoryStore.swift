//
//  WorkoutHistoryStore.swift
//  Sauna Tracker
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

    private static func session(from workout: HKWorkout) -> SaunaSession? {
        guard
            let jsonString = workout.metadata?[SessionMetadataPayload.metadataKey] as? String,
            let payload = SessionMetadataCoding.decode(jsonString)
        else { return nil }

        let kcal = workout.statistics(for: HealthKitTypes.activeEnergy)?
            .sumQuantity()?.doubleValue(for: .kilocalorie())

        return SaunaSession(
            id: UUID(),
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
