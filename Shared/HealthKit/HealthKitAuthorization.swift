//
//  HealthKitAuthorization.swift
//  Sauna Companion
//
//  Single source of truth for which HealthKit types this app touches, and
//  the authorization request used by both targets on launch.
//

import HealthKit

enum HealthKitTypes {
    static let heartRate = HKQuantityType(.heartRate)
    static let activeEnergy = HKQuantityType(.activeEnergyBurned)
    static let bodyMass = HKQuantityType(.bodyMass)
    static let workoutType = HKObjectType.workoutType()

    /// Types we read: heart rate during a session, body mass for the calorie
    /// formula, and workouts/energy for history.
    static var readTypes: Set<HKObjectType> {
        [workoutType, heartRate, activeEnergy, bodyMass]
    }

    /// Types we write: only from the Watch, while recording a session.
    static var shareTypes: Set<HKSampleType> {
        [workoutType, heartRate, activeEnergy]
    }
}

enum HealthKitAuthorization {
    static let healthStore: HKHealthStore? = HKHealthStore.isHealthDataAvailable() ? HKHealthStore() : nil

    @discardableResult
    static func requestAuthorization() async -> Bool {
        guard let healthStore else { return false }
        do {
            try await healthStore.requestAuthorization(
                toShare: HealthKitTypes.shareTypes,
                read: HealthKitTypes.readTypes
            )
            return true
        } catch {
            return false
        }
    }
}
