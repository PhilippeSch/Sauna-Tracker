//
//  CalorieCalculator.swift
//  Sauna Tracker
//
//  MET-based energy estimate. Only Sauna-phase time counts — Rest phases
//  contribute 0 kcal.
//

import Foundation

enum CalorieCalculator {
    /// kcal = MET × bodyWeightKg × durationInHours, summed over Sauna intervals only.
    static func activeEnergyKcal(
        saunaIntervals: [SaunaInterval],
        metValue: Double,
        bodyWeightKg: Double
    ) -> Double {
        let saunaSeconds = saunaIntervals
            .filter { $0.phase == .sauna }
            .reduce(0.0) { $0 + $1.duration }
        let hours = saunaSeconds / 3600
        return metValue * bodyWeightKg * hours
    }
}
