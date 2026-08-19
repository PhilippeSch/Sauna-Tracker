//
//  SessionStoreTests.swift
//  Sauna TrackerTests
//
//  The watch session state machine: rounds, phase alternation, the max-round
//  boundary, and what actually gets handed to HealthKit on finish.
//

import Testing
import Foundation
@testable import Sauna_Tracker

@MainActor
struct SessionStoreTests {

    @Test func startsInIdleAndBeginsFirstSaunaRound() async {
        let (store, recorder, haptics) = StoreFactory.make()
        #expect(store.isActive == false)

        await store.startSession()

        #expect(store.isActive)
        #expect(store.currentPhase == .sauna)
        #expect(store.roundCount == 1)
        #expect(recorder.startCallCount == 1)
        #expect(haptics.startCallCount == 1)
    }

    @Test func advancePhaseAlternatesAndCountsRounds() async {
        let (store, _, _) = StoreFactory.make()
        await store.startSession()

        store.advancePhase()
        #expect(store.currentPhase == .rest)
        #expect(store.roundCount == 1, "a rest phase must not count as a new round")

        store.advancePhase()
        #expect(store.currentPhase == .sauna)
        #expect(store.roundCount == 2)
    }

    @Test func advancePhaseIsBlockedAfterTheFinalRound() async {
        var settings = AppSettings.default
        settings.maxRounds = 2
        let (store, _, _) = StoreFactory.make(settings: settings)
        await store.startSession()

        store.advancePhase()  // rest after round 1
        store.advancePhase()  // round 2
        #expect(store.roundCount == 2)
        #expect(store.canStartAnotherRound == false)

        store.advancePhase()  // rest after the final round
        #expect(store.currentPhase == .rest)

        store.advancePhase()  // must not start round 3
        #expect(store.currentPhase == .rest)
        #expect(store.roundCount == 2)
    }

    @Test func endingIsAlwaysPossibleOnTheFinalRest() async {
        var settings = AppSettings.default
        settings.maxRounds = 1
        let (store, recorder, _) = StoreFactory.make(settings: settings)
        await store.startSession()
        store.advancePhase()  // rest after the only round

        await store.endSession()

        #expect(recorder.finishCallCount == 1)
        if case .summary = store.stage {} else {
            Issue.record("expected the summary stage after ending")
        }
    }

    @Test func firstRoundStartsWithTheSessionNotAfterHealthKitIsUp() async {
        let (store, recorder, _) = StoreFactory.make()
        recorder.startDelay = .milliseconds(150)

        await store.startSession()
        await store.endSession()

        let session = try? #require(recorder.lastFinishedSession)
        // Bringing HealthKit up takes a moment; the first round must still
        // line up with the session start rather than trail it.
        #expect(session?.startDate == session?.intervals.first?.startDate)
    }

    @Test func totalsAgreeAtTheStartOfASession() async {
        let (store, _, _) = StoreFactory.make()
        await store.startSession()

        // Sauna time and overall time must not drift apart before anything
        // has happened; they only diverge once a rest phase has run.
        #expect(abs(store.totalSessionDurationSoFar - store.totalSaunaDurationSoFar) < 0.05)
    }

    @Test func heartRateTracksCurrentAndRoundMaximum() async {
        let (store, recorder, _) = StoreFactory.make()
        await store.startSession()

        recorder.emitHeartRate(90)
        recorder.emitHeartRate(120)
        recorder.emitHeartRate(105)

        #expect(store.currentHeartRate == 105)
        #expect(store.maxHeartRateThisRound == 120)
    }

    @Test func roundMaximumResetsOnEachNewPhase() async {
        let (store, recorder, _) = StoreFactory.make()
        await store.startSession()
        recorder.emitHeartRate(140)
        #expect(store.maxHeartRateThisRound == 140)

        store.advancePhase()
        #expect(store.maxHeartRateThisRound == 0, "a new phase starts a fresh maximum")
        #expect(store.currentHeartRate == 140, "the live reading itself carries over")
    }

    @Test func finishedSessionRecordsEveryIntervalWithItsPeakHeartRate() async {
        let (store, recorder, _) = StoreFactory.make()
        await store.startSession()
        recorder.emitHeartRate(130)
        store.advancePhase()          // close sauna round 1
        recorder.emitHeartRate(95)
        await store.endSession()      // close the rest phase

        let session = try? #require(recorder.lastFinishedSession)
        #expect(session?.intervals.count == 2)
        #expect(session?.intervals.first?.phase == .sauna)
        #expect(session?.intervals.first?.maxHeartRateBPM == 130)
        #expect(session?.intervals.last?.phase == .rest)
        #expect(session?.intervals.last?.maxHeartRateBPM == 95)
        #expect(session?.roundCount == 1)
    }

    @Test func endSessionUsesResolvedBodyWeightAndConfiguredMet() async {
        var settings = AppSettings.default
        settings.metValue = 2.0
        let (store, recorder, _) = StoreFactory.make(settings: settings, bodyWeightKg: 90)
        await store.startSession()
        await store.endSession()

        #expect(recorder.lastBodyWeightKg == 90)
        #expect(recorder.lastFinishedSession?.metUsed == 2.0)
    }

    @Test func bodyWeightOverrideWinsOverHealthKit() async {
        var settings = AppSettings.default
        settings.bodyWeightOverrideKg = 65
        let (store, recorder, _) = StoreFactory.make(settings: settings, bodyWeightKg: 90)
        await store.startSession()
        await store.endSession()

        #expect(recorder.lastBodyWeightKg == 65)
    }

    @Test func aFailedSaveStillSurfacesASummaryWithTheError() async {
        struct Boom: LocalizedError {
            var errorDescription: String? { "no health access" }
        }
        let (store, recorder, _) = StoreFactory.make()
        recorder.errorToThrow = Boom()
        await store.startSession()
        await store.endSession()

        #expect(store.lastErrorDescription == "no health access")
        if case .summary = store.stage {} else {
            Issue.record("the session must still be shown even when saving fails")
        }
    }

    @Test func hapticsRestartOnEveryPhaseAndStopWhenTheSessionEnds() async {
        var settings = AppSettings.default
        settings.hapticIntervalMinutes = 3
        let (store, _, haptics) = StoreFactory.make(settings: settings)

        await store.startSession()
        #expect(haptics.lastInterval == 3)

        store.advancePhase()
        #expect(haptics.startCallCount == 2)

        await store.endSession()
        #expect(haptics.stopCallCount >= 2)
    }

    @Test func resetReturnsToIdleAndClearsLiveData() async {
        let (store, recorder, _) = StoreFactory.make()
        await store.startSession()
        recorder.emitHeartRate(110)
        await store.endSession()

        store.reset()

        #expect(store.isActive == false)
        #expect(store.roundCount == 0)
        #expect(store.currentHeartRate == nil)
        #expect(store.maxHeartRateThisRound == 0)
        #expect(store.intervals.isEmpty)
        #expect(store.lastErrorDescription == nil)
    }

    @Test func startingTwiceDoesNotRestartARunningSession() async {
        let (store, recorder, _) = StoreFactory.make()
        await store.startSession()
        await store.startSession()

        #expect(recorder.startCallCount == 1)
        #expect(store.roundCount == 1)
    }

    @Test func settingsPushedFromThePhoneApplyToTheRunningSession() async {
        let (store, _, _) = StoreFactory.make()
        await store.startSession()
        #expect(store.maxConfiguredRounds == 5)

        var updated = AppSettings.default
        updated.maxRounds = 2
        store.applySettings(updated)

        #expect(store.maxConfiguredRounds == 2)
        #expect(store.canStartAnotherRound, "one round done, two allowed")
    }
}
