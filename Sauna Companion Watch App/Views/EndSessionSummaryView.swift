//
//  EndSessionSummaryView.swift
//  Sauna Companion Watch App
//

import SwiftUI

struct EndSessionSummaryView: View {
    let session: SaunaSession
    let errorDescription: String?
    let onDone: () -> Void

    // Scrolls, unlike the other end-of-session screens: with an error message
    // in place the content outgrows a 40 mm screen, and a fixed frame had to
    // pay for it by truncating that message ("Nicht in Health ges…") — the one
    // line on this screen that has something to explain.
    var body: some View {
        ScrollView {
            content
        }
        .background(Color.black)
    }

    private var content: some View {
        VStack(spacing: 10) {
            Image(systemName: errorDescription == nil ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 28))
                .foregroundStyle(errorDescription == nil ? .green : .yellow)

            // Icon and message already switch on the error; the heading has
            // to follow, or it claims a save that did not happen.
            Text(errorDescription == nil ? "Session Saved" : "Not Saved")
                .font(.system(size: 16, weight: .semibold))

            VStack(spacing: 2) {
                summaryRow(label: "Rounds", value: "\(session.roundCount)")
                summaryRow(label: "Sauna Time", value: DurationFormatter.clock(session.totalSaunaDuration))
                if let kcal = session.activeEnergyKcal {
                    summaryRow(label: "Calories", value: "\(Int(kcal.rounded())) kcal")
                }
            }

            if let errorDescription {
                Text(errorDescription)
                    .font(.caption2)
                    .foregroundStyle(.yellow)
                    .multilineTextAlignment(.center)
                    // Take the lines the message needs instead of being
                    // squeezed onto one and trailing off in an ellipsis.
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button("Done", action: onDone)
                .buttonStyle(.borderedProminent)
                .tint(.orange)
        }
        .padding()
        .frame(maxWidth: .infinity)
    }

    private func summaryRow(label: LocalizedStringKey, value: String) -> some View {
        HStack {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.caption).monospacedDigit().foregroundStyle(.white)
        }
    }
}
