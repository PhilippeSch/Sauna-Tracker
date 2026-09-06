//
//  StatsView.swift
//  Sauna Companion
//

import SwiftUI

struct StatsView: View {
    @State private var sessions: [SaunaSession] = []
    @State private var period: StatsPeriod = .month
    @State private var isLoading = true
    private let connectivity = WatchConnectivityService.shared

    private var stats: SaunaStatistics {
        SaunaStatistics.compute(sessions: sessions, period: period)
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                } else {
                    content
                }
            }
            .navigationTitle("Statistics")
            .refreshable { await load() }
            .task { await load() }
            .onChange(of: connectivity.lastSavedWorkoutUUID) { _, _ in
                Task { await load() }
            }
        }
    }

    private var content: some View {
        ScrollView {
            VStack(spacing: 16) {
                Picker("Period", selection: $period) {
                    ForEach(StatsPeriod.allCases) { period in
                        Text(period.title).tag(period)
                    }
                }
                .pickerStyle(.segmented)

                let stats = stats
                if stats.isEmpty {
                    ContentUnavailableView(
                        "No Data",
                        systemImage: "chart.bar",
                        description: Text("No sauna sessions in this period.")
                    )
                    .padding(.top, 40)
                } else {
                    headline(stats)
                    grid(stats)
                    habits(stats)
                }
            }
            .padding()
        }
    }

    private func headline(_ stats: SaunaStatistics) -> some View {
        VStack(spacing: 4) {
            Text(DurationFormatter.abbreviated(stats.totalSaunaTime))
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundStyle(.orange)
            Text("Total Sauna Time")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private func grid(_ stats: SaunaStatistics) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatCard(title: "Sessions", value: "\(stats.sessionCount)", symbol: "flame.fill", tint: .orange)
            StatCard(title: "Rounds", value: "\(stats.totalRounds)", symbol: "repeat", tint: .orange)
            StatCard(
                title: "Avg. Round",
                value: DurationFormatter.abbreviated(stats.averageRoundDuration),
                symbol: "timer", tint: .teal
            )
            StatCard(
                title: "Avg. Session",
                value: DurationFormatter.abbreviated(stats.averageSessionSaunaTime),
                symbol: "clock", tint: .teal
            )
            StatCard(
                title: "Total Calories",
                value: "\(Int(stats.totalCalories.rounded())) kcal",
                symbol: "bolt.fill", tint: .yellow
            )
            StatCard(
                title: "Avg. Calories",
                value: "\(Int(stats.averageCaloriesPerSession.rounded())) kcal",
                symbol: "bolt", tint: .yellow
            )
            if let avgMax = stats.averageMaxHeartRate {
                StatCard(title: "Avg. Max HR", value: "\(Int(avgMax.rounded())) bpm", symbol: "heart", tint: .red)
            }
            if let peak = stats.peakHeartRate {
                StatCard(title: "Peak HR", value: "\(Int(peak.rounded())) bpm", symbol: "heart.fill", tint: .red)
            }
            StatCard(
                title: "Longest Session",
                value: DurationFormatter.abbreviated(stats.longestSessionSaunaTime),
                symbol: "trophy.fill", tint: .indigo
            )
            StatCard(
                title: "Rest Time",
                value: DurationFormatter.abbreviated(stats.totalRestTime),
                symbol: "pause.circle", tint: .teal
            )
        }
    }

    @ViewBuilder
    private func habits(_ stats: SaunaStatistics) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Habits")
                .font(.headline)
            if let weekday = stats.mostFrequentWeekday {
                habitRow(
                    label: "Favourite Day",
                    value: Calendar.current.weekdaySymbols[weekday - 1],
                    symbol: "calendar"
                )
            }
            if let hour = stats.mostFrequentHour {
                habitRow(label: "Favourite Time", value: hourLabel(hour), symbol: "sun.horizon")
            }
            if let date = stats.longestSessionDate {
                habitRow(
                    label: "Longest Session On",
                    value: date.formatted(.dateTime.day().month(.abbreviated).year()),
                    symbol: "star"
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private func habitRow(label: LocalizedStringKey, value: String, symbol: String) -> some View {
        HStack {
            Label(label, systemImage: symbol)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.medium))
        }
    }

    private func hourLabel(_ hour: Int) -> String {
        var components = DateComponents()
        components.hour = hour
        components.minute = 0
        let date = Calendar.current.date(from: components) ?? .now
        return date.formatted(.dateTime.hour())
    }

    private func load() async {
        sessions = await WorkoutHistoryStore.fetchAllSessions()
        isLoading = false
    }
}

struct StatCard: View {
    let title: LocalizedStringKey
    let value: String
    let symbol: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: symbol)
                .font(.caption)
                .foregroundStyle(tint)
                .lineLimit(1)
            Text(value)
                .font(.title3.weight(.semibold))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }
}

#Preview {
    StatsView()
}
