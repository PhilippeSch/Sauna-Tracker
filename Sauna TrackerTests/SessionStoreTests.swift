//
//  SessionStoreTests.swift
//  Sauna TrackerTests
//
//  The watch session state machine: rounds, phase alternation, and what
//  actually gets handed to HealthKit on finish.
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

    @Test func roundsAreNotCapped() async {
        let (store, _, _) = StoreFactory.make()
        await store.startSession()

        // Ten rounds, well past any number a session would realistically
        // reach: the button must keep working instead of running out.
        for _ in 1..<10 {
            store.advancePhase()  // rest
            store.advancePhase()  // next round
        }

        #expect(store.currentPhase == .sauna)
        #expect(store.roundCount == 10)
    }

    @Test func endingIsPossibleDuringARestPhase() async {
        let (store, recorder, _) = StoreFactory.make()
        await store.startSession()
        store.advancePhase()  // rest after the first round

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

    @Test func creatingAStoreDoesNotHijackTheCurrentOne() async {
        let (live, _, _) = StoreFactory.make()
        live.makeCurrent()
        await live.startSession()

        // SwiftUI evaluates a @State default-value expression on every view
        // init and throws the extra instances away. When init registered
        // itself, `current` ended up on a discarded store and — being weak —
        // went nil, which is why the Action button did nothing.
        _ = StoreFactory.make()
        _ = StoreFactory.make()

        #expect(SessionStore.current === live)
        #expect(SessionStore.current?.isActive == true)
    }

    @Test func theRegisteredStoreIsTheOneIntentsAdvance() async {
        let (live, _, _) = StoreFactory.make()
        live.makeCurrent()
        await live.startSession()
        #expect(live.currentPhase == .sauna)

        // Stands in for what the Action button's phase toggle does.
        SessionStore.current?.advancePhase()

        #expect(live.currentPhase == .rest)
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

    @Test func hapticsRunDuringSaunaRoundsOnly() async {
        var settings = AppSettings.default
        settings.hapticIntervalMinutes = 3
        let (store, _, haptics) = StoreFactory.make(settings: settings)

        await store.startSession()
        #expect(haptics.startCallCount == 1, "the first sauna round schedules taps")
        #expect(haptics.lastInterval == 3)

        store.advancePhase()  // into rest
        #expect(haptics.startCallCount == 1, "a rest phase must not schedule taps")
        #expect(haptics.stopCallCount >= 1, "and must cancel the running scheduler")

        store.advancePhase()  // back into sauna
        #expect(haptics.startCallCount == 2, "taps resume with the next round")
    }

    @Test func hapticsStopWhenTheSessionEnds() async {
        let (store, _, haptics) = StoreFactory.make()
        await store.startSession()
        await store.endSession()
        #expect(haptics.stopCallCount >= 1)
    }

    @Test func hapticsNeverStartWhenVibrationIsSwitchedOff() async {
        var settings = AppSettings.default
        settings.hapticIntervalMinutes = AppSettings.hapticsOff
        let (store, _, haptics) = StoreFactory.make(settings: settings)

        await store.startSession()
        store.advancePhase()
        store.advancePhase()

        #expect(haptics.startCallCount == 0)
    }

    @Test func discardingASessionSavesNothingAndReturnsToIdle() async {
        let (store, recorder, haptics) = StoreFactory.make()
        await store.startSession()
        store.advancePhase()

        await store.discardSession()

        #expect(recorder.discardCallCount == 1)
        #expect(recorder.finishCallCount == 0, "a discarded session must never reach HealthKit")
        #expect(store.isActive == false)
        #expect(store.roundCount == 0)
        #expect(store.intervals.isEmpty)
        #expect(haptics.stopCallCount >= 1)
    }

    @Test func discardingIsIgnoredWhenNoSessionIsRunning() async {
        let (store, recorder, _) = StoreFactory.make()
        await store.discardSession()
        #expect(recorder.discardCallCount == 0)
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
        #expect(store.settings.metValue == AppSettings.default.metValue)

        var updated = AppSettings.default
        updated.metValue = 1.9
        store.applySettings(updated)

        #expect(store.settings.metValue == 1.9)
    }
}
