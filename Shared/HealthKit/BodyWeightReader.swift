//
//  BodyWeightReader.swift
//  Sauna Tracker
//

import HealthKit

enum BodyWeightReader {
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
            ) { _, samples, _ in
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
