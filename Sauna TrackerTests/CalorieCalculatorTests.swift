//
//  CalorieCalculatorTests.swift
//  Sauna TrackerTests
//

import Testing
import Foundation
@testable import Sauna_Tracker

struct CalorieCalculatorTests {

    @Test func onlyCountsSaunaIntervals() {
        let start = Fixture.reference
        let sauna = Fixture.interval(.sauna, start: start, seconds: 600)
        let rest = Fixture.interval(.rest, start: start.addingTimeInterval(600), seconds: 600)

        let kcal = CalorieCalculator.activeEnergyKcal(
            saunaIntervals: [sauna, rest], metValue: 1.75, bodyWeightKg: 80
        )

        // 10 minutes of sauna only: 1.75 * 80 * (1/6) h
        #expect(abs(kcal - 23.333) < 0.01)
    }

    @Test func restOnlyInputBurnsNothing() {
        let rest = Fixture.interval(.rest, start: Fixture.reference, seconds: 1800)
        let kcal = CalorieCalculator.activeEnergyKcal(
            saunaIntervals: [rest], metValue: 1.75, bodyWeightKg: 80
        )
        #expect(kcal == 0)
    }

    @Test func noIntervalsYieldsZeroCalories() {
        let kcal = CalorieCalculator.activeEnergyKcal(saunaIntervals: [], metValue: 1.75, bodyWeightKg: 80)
        #expect(kcal == 0)
    }

    @Test func matchesTheMetFormulaExactly() {
        // One hour makes the arithmetic obvious: MET * kg * 1h
        let hour = Fixture.interval(.sauna, start: Fixture.reference, seconds: 3600)
        let kcal = CalorieCalculator.activeEnergyKcal(
            saunaIntervals: [hour], metValue: 1.75, bodyWeightKg: 100
        )
        #expect(abs(kcal - 175) < 0.0001)
    }

    @Test func scalesLinearlyWithMetAndWeight() {
        let round = Fixture.interval(.sauna, start: Fixture.reference, seconds: 900)
        let low = CalorieCalculator.activeEnergyKcal(saunaIntervals: [round], metValue: 1.5, bodyWeightKg: 80)
        let highMet = CalorieCalculator.activeEnergyKcal(saunaIntervals: [round], metValue: 2.0, bodyWeightKg: 80)
        let highWeight = CalorieCalculator.activeEnergyKcal(saunaIntervals: [round], metValue: 1.5, bodyWeightKg: 160)

        #expect(highMet > low)
        #expect(abs(highMet / low - (2.0 / 1.5)) < 0.0001)
        #expect(abs(highWeight - low * 2) < 0.0001)
    }

    @Test func multipleRoundsSumTogether() {
        let start = Fixture.reference
        let rounds = [
            Fixture.interval(.sauna, start: start, seconds: 600),
            Fixture.interval(.rest, start: start.addingTimeInterval(600), seconds: 300),
            Fixture.interval(.sauna, start: start.addingTimeInterval(900), seconds: 600),
        ]
        let combined = CalorieCalculator.activeEnergyKcal(
            saunaIntervals: rounds, metValue: 1.75, bodyWeightKg: 80
        )
        let single = CalorieCalculator.activeEnergyKcal(
            saunaIntervals: [rounds[0]], metValue: 1.75, bodyWeightKg: 80
        )
        #expect(abs(combined - single * 2) < 0.0001)
    }
}
