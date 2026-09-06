//
//  SessionDetailView.swift
//  Sauna Companion
//
//  Round-by-round breakdown of one session, plus the note editor. Saving a
//  note rewrites the workout in Health (see WorkoutNotesEditor), so the view
//  reports progress and failures rather than pretending it always succeeds.
//  The rewrite hands back a new workout UUID, which is why the session is
//  held in @State: a second save has to address the replacement, not the
//  original that no longer exists.
//

import SwiftUI

struct SessionDetailView: View {
    var onNotesSaved: () -> Void

    @State private var session: SaunaSession
    @State private var noteText: String
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var savedSuccessfully = false
    @FocusState private var noteFocused: Bool

    // Both pieces of state are seeded here rather than in onAppear, so an
    // unsaved draft survives a trip through the background instead of being
    // overwritten with the stored note every time the view reappears.
    init(session: SaunaSession, onNotesSaved: @escaping () -> Void) {
        self.onNotesSaved = onNotesSaved
        _session = State(initialValue: session)
        _noteText = State(initialValue: session.notes ?? "")
    }

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
                    Text("For example: Finnish sauna 90 °C, Aufguss menthol.\nStored with the session, visible only in Sauna Companion.")
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
            let replacementUUID = try await WorkoutNotesEditor.updateNotes(for: session, notes: noteText)
            // Health cannot patch a stored workout, so the note lands on a
            // replacement with a fresh UUID. Follow it, or the next save
            // would look for a workout that has just been deleted.
            let trimmed = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
            session.healthKitWorkoutUUID = replacementUUID
            session.notes = trimmed.isEmpty ? nil : trimmed
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
