//
//  SessionDetailView.swift
//  Sauna Tracker
//
//  Round-by-round breakdown of one session, plus the note editor. Saving a
//  note rewrites the workout in Health (see WorkoutNotesEditor), so the view
//  reports progress and failures rather than pretending it always succeeds.
//

import SwiftUI

struct SessionDetailView: View {
    let session: SaunaSession
    var onNotesSaved: () -> Void

    @State private var noteText: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var savedSuccessfully = false
    @FocusState private var noteFocused: Bool

    private var hasUnsavedChanges: Bool {
        noteText.trimmingCharacters(in: .whitespacesAndNewlines) != (session.notes ?? "")
    }

    var body: some View {
        Form {
            Section("Summary") {
                row("Rounds", "\(session.roundCount)")
                row("Sauna Time", DurationFormatter.abbreviated(session.totalSaunaDuration))
                row("Rest Time", DurationFormatter.abbreviated(session.totalRestDuration))
                row("Total", DurationFormatter.abbreviated(session.totalDuration))
                if let kcal = session.activeEnergyKcal {
                    row("Calories", "\(Int(kcal.rounded())) kcal")
                }
                if let maxHR = session.maxHeartRateBPM {
                    row("Max Heart Rate", "\(Int(maxHR.rounded())) bpm")
                }
                row("MET", String(format: "%.2f", session.metUsed))
            }

            Section("Rounds") {
                ForEach(Array(session.intervals.enumerated()), id: \.element.id) { index, interval in
                    IntervalRow(interval: interval, number: saunaRoundNumber(upTo: index))
                }
            }

            Section {
                TextField("Add a note…", text: $noteText, axis: .vertical)
                    .lineLimit(2...6)
                    .focused($noteFocused)

                Button {
                    Task { await saveNote() }
                } label: {
                    HStack {
                        if isSaving { ProgressView().padding(.trailing, 4) }
                        Text("Save Note")
                    }
                }
                .disabled(isSaving || !hasUnsavedChanges)
            } header: {
                Text("Notes")
            } footer: {
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red)
                } else if savedSuccessfully {
                    Text("Note saved.").foregroundStyle(.green)
                } else {
                    // The note travels with the workout in Health, but Health
                    // and Fitness never render third-party workout metadata,
                    // so say plainly where it will and will not show up.
                    Text("For example: Finnish sauna 90 °C, Aufguss menthol.\nStored with the session, visible only in Sauna Tracker.")
                }
            }
        }
        .navigationTitle(session.startDate.formatted(.dateTime.day().month().year()))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .keyboard) {
                Button("Done") { noteFocused = false }
            }
        }
        .onAppear { noteText = session.notes ?? "" }
    }

    /// Sauna rounds are numbered; rest intervals show no number.
    private func saunaRoundNumber(upTo index: Int) -> Int? {
        guard session.intervals[index].phase == .sauna else { return nil }
        return session.intervals[0...index].filter { $0.phase == .sauna }.count
    }

    private func row(_ label: LocalizedStringKey, _ value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value).foregroundStyle(.secondary)
        }
    }

    private func saveNote() async {
        isSaving = true
        errorMessage = nil
        savedSuccessfully = false
        noteFocused = false
        do {
            try await WorkoutNotesEditor.updateNotes(for: session, notes: noteText)
            savedSuccessfully = true
            onNotesSaved()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }
}

struct IntervalRow: View {
    let interval: SaunaInterval
    let number: Int?

    var body: some View {
        HStack {
            Circle()
                .fill(interval.phase.tintColor)
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.subheadline)
                Text(interval.startDate, format: .dateTime.hour().minute())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text(DurationFormatter.abbreviated(interval.duration))
                    .font(.subheadline.monospacedDigit())
                if let hr = interval.maxHeartRateBPM {
                    Text("\(Int(hr.rounded())) bpm")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var title: String {
        if let number {
            return String(
                localized: "round.number",
                defaultValue: "Round \(number)"
            )
        }
        return interval.phase.displayName
    }
}
