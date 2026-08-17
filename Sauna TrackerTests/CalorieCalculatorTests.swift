//
//  CalorieCalculatorTests.swift
//  Sauna TrackerTests
//

import Testing
import Foundation
@testable import Sauna_Tracker

struct CalorieCalculatorTests {
    @Test func onlyCountsSaunaIntervals() {
        let start = Date()
        let sauna = SaunaInterval(phase: .sauna, startDate: start, endDate: start.addingTimeInterval(600))
        let rest = SaunaInterval(phase: .rest, startDate: start, endDate: start.addingTimeInterval(600))

        let kcal = CalorieCalculator.activeEnergyKcal(
            saunaIntervals: [sauna, rest],
            metValue: 1.75,
            bodyWeightKg: 80
        )

        // 10 minutes sauna only = 1/6 hour; 1.75 * 80 * (1/6) ≈ 23.33 kcal
        #expect(abs(kcal - 23.33) < 0.1)
    }

    @Test func noIntervalsYieldsZeroCalories() {
        let kcal = CalorieCalculator.activeEnergyKcal(saunaIntervals: [], metValue: 1.75, bodyWeightKg: 80)
        #expect(kcal == 0)
    }

    @Test func higherMetYieldsMoreCalories() {
        let start = Date()
        let sauna = SaunaInterval(phase: .sauna, startDate: start, endDate: start.addingTimeInterval(600))

        let low = CalorieCalculator.activeEnergyKcal(saunaIntervals: [sauna], metValue: 1.5, bodyWeightKg: 80)
        let high = CalorieCalculator.activeEnergyKcal(saunaIntervals: [sauna], metValue: 2.0, bodyWeightKg: 80)

        #expect(high > low)
    }
}
