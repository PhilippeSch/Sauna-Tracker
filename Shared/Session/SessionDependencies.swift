//
//  SessionDependencies.swift
//  Sauna Tracker
//
//  The seams SessionStore is written against. The watch supplies the real
//  HealthKit recorder and WatchKit haptics; tests supply fakes, which is what
//  keeps the round/phase state machine verifiable without a wrist on a device.
//

import Foundation

@MainActor
protocol SessionRecording: AnyObject {
    /// False when HealthKit refused to start a live workout.
    var isRecording: Bool { get }
    var onHeartRateUpdate: ((Double) -> Void)? { get set }
    var onSensorReadingsUpdate: ((RoundSensorReadings) -> Void)? { get set }

    func startWorkoutSession(startDate: Date) async
    func finishAndSave(
        session: SaunaSession,
        maxRoundsConfigured: Int,
        bodyWeightKg: Double
    ) async throws -> UUID
    /// Ends the live workout and throws it away — nothing reaches Health.
    func discard() async
}

@MainActor
protocol HapticScheduling: AnyObject {
    func start(intervalMinutes: Int)
    func stop()
}

/// Resolves the body weight used for the MET calculation. Injected so tests
/// don't depend on whatever HealthKit happens to hold.
typealias BodyWeightProviding = @MainActor (_ override: Double?) async -> Double?

@MainActor
enum DefaultBodyWeightProvider {
    static let live: BodyWeightProviding = { override in
        await BodyWeightReader.resolvedBodyWeightKg(override: override)
    }
}
