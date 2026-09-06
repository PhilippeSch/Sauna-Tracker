//
//  WorkoutNotesEditor.swift
//  Sauna Companion
//
//  HealthKit has no API to patch metadata on an already saved HKWorkout, so
//  editing a note means writing a replacement workout and removing the old
//  one. Order matters, and the rule throughout is that the original is only
//  ever deleted once the replacement is known to be complete:
//
//    1. Save the replacement, with the original's heart-rate and energy
//       samples re-attached, and confirm it.
//    2. Only then delete the original — HealthKit takes the samples it owns
//       down with it, so a replacement missing them would lose the curve.
//
//  If re-attaching the samples fails, the part-built replacement is discarded
//  and the original is left untouched. Every failure therefore ends in an
//  unchanged session, or at worst a duplicate, but never in a session
//  stripped of its heart rate.
//

import Foundation
import HealthKit
import os

enum WorkoutNotesEditor {
    private static let log = Logger(subsystem: "Scheuber.Sauna-Tracker", category: "NotesEditor")

    enum EditError: LocalizedError {
        case healthUnavailable
        case workoutNotFound
        case saveFailed

        var errorDescription: String? {
            switch self {
            case .healthUnavailable:
                String(localized: "notes.error.unavailable", defaultValue: "Health is not available.")
            case .workoutNotFound:
                String(localized: "notes.error.notFound", defaultValue: "This session is no longer in Health.")
            case .saveFailed:
                String(localized: "notes.error.saveFailed", defaultValue: "Could not save the note to Health.")
            }
        }
    }

    /// Replaces the stored session with an identical one carrying `notes`.
    /// Returns the new workout UUID.
    @discardableResult
    static func updateNotes(for session: SaunaSession, notes: String?) async throws -> UUID {
        guard let store = HealthKitAuthorization.healthStore else { throw EditError.healthUnavailable }
        guard let workoutUUID = session.healthKitWorkoutUUID,
              let original = await workout(withUUID: workoutUUID, store: store)
        else { throw EditError.workoutNotFound }

        let trimmed = notes?.trimmingCharacters(in: .whitespacesAndNewlines)
        var updated = session
        updated.notes = (trimmed?.isEmpty ?? true) ? nil : trimmed

        // Samples currently attached to the workout, so the replacement keeps
        // the same heart rate and energy data.
        let attached = await attachedSamples(of: original, store: store)

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .other
        configuration.locationType = .indoor

        let builder = HKWorkoutBuilder(healthStore: store, configuration: configuration, device: .local())
        try await builder.beginCollection(at: original.startDate)

        if !attached.isEmpty {
            do {
                try await builder.addSamples(attached)
            } catch {
                // Carrying on would save a replacement without the heart-rate
                // curve and then delete the original that still has it. Throw
                // the part-built replacement away instead — nothing is in
                // Health until finishWorkout — and leave Health as it was.
                log.error("Could not re-attach \(attached.count) sample(s): \(error.localizedDescription)")
                builder.discardWorkout()
                throw EditError.saveFailed
            }
        }

        var metadata = original.metadata ?? [:]
        let payload = SessionMetadataPayload(session: updated)
        if let encoded = SessionMetadataCoding.encode(payload) {
            metadata[SessionMetadataPayload.metadataKey] = encoded
        }
        try await builder.addMetadata(metadata)
        try await builder.endCollection(at: original.endDate)

        guard let replacement = try await builder.finishWorkout() else { throw EditError.saveFailed }
        log.info("Saved replacement workout \(replacement.uuid.uuidString)")

        // Only now is it safe to remove the original.
        do {
            try await store.delete(original)
            log.info("Deleted original workout \(original.uuid.uuidString)")
        } catch {
            log.error("Replacement saved but original could not be deleted: \(error.localizedDescription)")
            throw EditError.saveFailed
        }

        return replacement.uuid
    }

    private static func workout(withUUID uuid: UUID, store: HKHealthStore) async -> HKWorkout? {
        await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HealthKitTypes.workoutType,
                predicate: HKQuery.predicateForObject(with: uuid),
                limit: 1,
                sortDescriptors: nil
            ) { _, samples, _ in
                continuation.resume(returning: samples?.first as? HKWorkout)
            }
            store.execute(query)
        }
    }

    private static func attachedSamples(of workout: HKWorkout, store: HKHealthStore) async -> [HKSample] {
        var collected: [HKSample] = []
        for type in [HealthKitTypes.heartRate, HealthKitTypes.activeEnergy] {
            let samples: [HKSample] = await withCheckedContinuation { continuation in
                let query = HKSampleQuery(
                    sampleType: type,
                    predicate: HKQuery.predicateForObjects(from: workout),
                    limit: HKObjectQueryNoLimit,
                    sortDescriptors: nil
                ) { _, samples, _ in
                    continuation.resume(returning: samples ?? [])
                }
                store.execute(query)
            }
            collected.append(contentsOf: samples)
        }
        return collected
    }
}
