//
//  EndSessionSummaryView.swift
//  Sauna Companion Watch App
//

import SwiftUI

struct EndSessionSummaryView: View {
    let session: SaunaSession
    let errorDescription: String?
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: errorDescription == nil ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 28))
                .foregroundStyle(errorDescription == nil ? .green : .yellow)

            Text("Session Saved")
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
            }

            Button("Done", action: onDone)
                .buttonStyle(.borderedProminent)
                .tint(.orange)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }

    private func summaryRow(label: LocalizedStringKey, value: String) -> some View {
        HStack {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.caption).monospacedDigit().foregroundStyle(.white)
        }
    }
}
