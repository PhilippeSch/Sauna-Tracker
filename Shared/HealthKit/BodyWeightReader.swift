//
//  BodyWeightReader.swift
//  Sauna Companion
//

import HealthKit
import os

enum BodyWeightReader {
    private static let log = Logger(subsystem: "Scheuber.Sauna-Tracker", category: "BodyWeight")

    /// Most recent body mass sample from HealthKit, in kilograms.
    static func latestBodyWeightKg() async -> Double? {
        guard let healthStore = HealthKitAuthorization.healthStore else { return nil }
        let sort = [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HealthKitTypes.bodyMass,
                predicate: nil,
                limit: 1,
                sortDescriptors: sort
            ) { _, samples, error in
                // Otherwise a refused read is indistinguishable from a user
                // who has simply never recorded a weight.
                if let error {
                    log.error("Reading body mass failed: \(error.localizedDescription)")
                }
                let kg = (samples?.first as? HKQuantitySample)?
                    .quantity.doubleValue(for: .gramUnit(with: .kilo))
                continuation.resume(returning: kg)
            }
            healthStore.execute(query)
        }
    }

    /// Resolves the weight to use for the calorie formula: an explicit
    /// override always wins, otherwise fall back to HealthKit.
    static func resolvedBodyWeightKg(override: Double?) async -> Double? {
        if let override { return override }
        return await latestBodyWeightKg()
    }
}
