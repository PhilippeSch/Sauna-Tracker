//
//  ActiveSessionView.swift
//  Sauna Tracker Watch App
//
//  Metrics page of a running session. Near-black background for contrast and
//  Always-On power draw; the phase is carried by the colour of the elapsed
//  timer, with no label competing with it for space.
//
//  Ending a session lives on the controls page (swipe) only, so this screen
//  keeps a single unmistakable action.
//

import SwiftUI

struct ActiveSessionView: View {
    @Bindable var store: SessionStore

    // Text(timerInterval:) stops counting at the end of the range, so this
    // bound has to be further out than any plausible phase — an hour was not.
    private var phaseEndBound: Date {
        store.phaseStartDate.addingTimeInterval(SaunaPhase.maxDisplayedPhaseDuration)
    }

    private var isLastRound: Bool {
        store.currentPhase == .rest && !store.canStartAnotherRound
    }

    var body: some View {
        VStack(spacing: 4) {
            Text(timerInterval: store.phaseStartDate...phaseEndBound, countsDown: false)
                .font(.system(size: 42, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .layoutPriority(1)
                .foregroundStyle(store.currentPhase.tintColor)

            roundIndicator
            heartRateBlock

            if !store.isRecordingToHealth {
                notRecordingWarning
            }

            Spacer(minLength: 0)

            if isLastRound {
                // No round left to start, and ending is a swipe away — say so
                // rather than leaving a button that cannot do anything.
                swipeHint
            } else {
                Button {
                    store.advancePhase()
                } label: {
                    Text(store.currentPhase == .sauna ? "Rest" : "Next Round")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity, minHeight: 46)
                }
                .buttonStyle(.borderedProminent)
                .tint(store.currentPhase.tintColor)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 2)
        // Negative, on purpose: this screen has no title, so the band watchOS
        // reserves above the safe area sits empty and pushed the whole block
        // down. Reclaiming most of it lifts the timer without letting it run
        // into the system clock; the button keeps its place at the bottom.
        .padding(.top, -14)
    }

    private var roundIndicator: some View {
        HStack(spacing: 4) {
            ForEach(0..<store.maxConfiguredRounds, id: \.self) { index in
                Circle()
                    .fill(index < store.roundCount ? store.currentPhase.tintColor : Color.white.opacity(0.25))
                    .frame(width: 5, height: 5)
            }
            Text("Round \(store.roundCount) of \(store.maxConfiguredRounds)")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .padding(.leading, 3)
        }
    }

    private var heartRateBlock: some View {
        HStack(alignment: .center, spacing: 12) {
            HStack(spacing: 3) {
                Image(systemName: "heart.fill")
                    .foregroundStyle(.red)
                    .font(.system(size: 14))
                Text(store.currentHeartRate.map { "\(Int($0))" } ?? "–")
                    .font(.system(size: 26, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
            }

            HStack(spacing: 3) {
                Text(store.maxHeartRateThisRound > 0 ? "\(Int(store.maxHeartRateThisRound))" : "–")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.85))
                Text("MAX")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(0.5)
                    .foregroundStyle(.secondary)
            }
        }
        // Centred as one block, in line with the timer and round indicator
        // above it. Scales down rather than clipping when both values are
        // three digits on a small watch.
        .frame(maxWidth: .infinity, alignment: .center)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .padding(.horizontal, 4)
    }

    private var notRecordingWarning: some View {
        Label("Not saving to Health", systemImage: "exclamationmark.triangle.fill")
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.yellow)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
    }

    private var swipeHint: some View {
        HStack(spacing: 5) {
            Image(systemName: "chevron.left")
            Text("Swipe to finish")
        }
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, minHeight: 46)
    }
}
