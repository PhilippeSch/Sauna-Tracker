//
//  SessionRowView.swift
//  Sauna Tracker
//

import SwiftUI

struct SessionRowView: View {
    let session: SaunaSession

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.startDate, format: .dateTime.weekday(.wide).month().day())
                    .font(.headline)
                HStack(spacing: 6) {
                    Text(session.startDate, format: .dateTime.hour().minute())
                    if let notes = session.notes, !notes.isEmpty {
                        Image(systemName: "note.text")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("^[\(session.roundCount) round](inflect: true)")
                    .font(.subheadline)
                HStack(spacing: 8) {
                    Label(DurationFormatter.abbreviated(session.totalSaunaDuration), systemImage: "flame")
                    if let kcal = session.activeEnergyKcal {
                        Label("\(Int(kcal.rounded())) kcal", systemImage: "bolt.fill")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
