//
//  ActiveSessionView.swift
//  Sauna Tracker Watch App
//
//  Metrics page of a running session. Near-black background for contrast and
//  Always-On power draw; the phase is carried by the navigation title plus
//  the colour of the elapsed timer rather than a full screen tint.
//
//  Deliberately a fixed VStack rather than a ScrollView: both action buttons
//  must be on screen at all times, because scrolling to end a session with
//  wet hands in a hot room is exactly what we are designing against. The
//  optional sensor readings live on the controls page instead.
//

import SwiftUI

struct ActiveSessionView: View {
    @Bindable var store: SessionStore
    var onEndRequested: () -> Void

    private var phaseEndBound: Date {
        store.phaseStartDate.addingTimeInterval(3600)
    }

    private var isLastRound: Bool {
        store.currentPhase == .rest && !store.canStartAnotherRound
    }

    var body: some View {
        VStack(spacing: 4) {
            Text(timerInterval: store.phaseStartDate...phaseEndBound, countsDown: false)
                .font(.system(size: 36, weight: .semibold, design: .rounded))
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

            actionButtons
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 2)
        // Keeps the big timer clear of the navigation title, which shares the
        // top band with the system clock.
        .padding(.top, 14)
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

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

    @ViewBuilder
    private var actionButtons: some View {
        VStack(spacing: 5) {
            // On the last round's rest there is no next round to start, so the
            // primary action becomes ending the session rather than a dead button.
            if isLastRound {
                Button(action: onEndRequested) {
                    Label("End Session", systemImage: "stop.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            } else {
                Button {
                    store.advancePhase()
                } label: {
                    Text(store.currentPhase == .sauna ? "Rest" : "Next Round")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity, minHeight: 42)
                }
                .buttonStyle(.borderedProminent)
                .tint(store.currentPhase.tintColor)

                Button(action: onEndRequested) {
                    Label("End Session", systemImage: "stop.fill")
                        .font(.system(size: 13, weight: .medium))
                        .frame(maxWidth: .infinity, minHeight: 30)
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
        }
    }
}
