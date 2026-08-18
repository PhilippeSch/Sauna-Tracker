//
//  AlwaysOnSessionView.swift
//  Sauna Tracker Watch App
//
//  What stays on screen when the wrist is down. Deliberately only three
//  things — phase, elapsed time and pulse — in a dim, low-power palette.
//  The heart rate shown here is the last value the system delivered; watchOS
//  throttles sensor updates in this state, so it can lag the live screen.
//

import SwiftUI

struct AlwaysOnSessionView: View {
    @Bindable var store: SessionStore

    private var phaseEndBound: Date {
        store.phaseStartDate.addingTimeInterval(6 * 3600)
    }

    var body: some View {
        VStack(spacing: 6) {
            Text(store.currentPhase.displayName.uppercased())
                .font(.system(size: 13, weight: .bold))
                .tracking(1.5)
                .foregroundStyle(store.currentPhase.tintColor)

            Text(timerInterval: store.phaseStartDate...phaseEndBound, countsDown: false)
                .font(.system(size: 38, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .foregroundStyle(.white)

            HStack(spacing: 5) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.red)
                Text(store.currentHeartRate.map { "\(Int($0))" } ?? "–")
                    .font(.system(size: 26, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                Text("BPM")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Text("Round \(store.roundCount) of \(store.maxConfiguredRounds)")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
