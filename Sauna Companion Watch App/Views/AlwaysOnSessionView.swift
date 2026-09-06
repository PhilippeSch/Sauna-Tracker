//
//  AlwaysOnSessionView.swift
//  Sauna Companion Watch App
//
//  What stays on screen when the wrist is down. Deliberately only three
//  things — phase, elapsed time and pulse — in a dim, low-power palette.
//
//  The elapsed time is rendered from a TimelineView rather than
//  Text(timerInterval:): watchOS drops the seconds from a timer text once the
//  luminance is reduced, which showed up as "5:–". A running HKWorkoutSession
//  earns the app a faster Always-On cadence than the once-a-minute default,
//  so driving the label ourselves keeps the seconds visible.
//
//  The heart rate here is the last value the system delivered; watchOS
//  throttles sensor updates in this state, so it can lag the live screen.
//

import SwiftUI

struct AlwaysOnSessionView: View {
    @Bindable var store: SessionStore

    var body: some View {
        VStack(spacing: 6) {
            Text(store.currentPhase.displayName.uppercased())
                .font(.system(size: 13, weight: .bold))
                .tracking(1.5)
                .foregroundStyle(store.currentPhase.tintColor)

            TimelineView(.periodic(from: store.phaseStartDate, by: 1)) { context in
                Text(DurationFormatter.clock(context.date.timeIntervalSince(store.phaseStartDate)))
                    .font(.system(size: 38, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .foregroundStyle(.white)
            }

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

            Text("Round \(store.roundCount)")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
