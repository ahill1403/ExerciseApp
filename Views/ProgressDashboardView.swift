//
//  ProgressDashboardView.swift
//  REPS
//
//  Created by Aaron Hill on 9/11/25.
//

import SwiftUI
import Charts

struct ProgressDashboardView: View {
    @StateObject private var vm = ProgressViewModel()

    var body: some View {
        ZStack { NeonMotionBackground() }
            .overlay(
                ScrollView {
                    VStack(spacing: 16) {
                        // Tiles
                        HStack(spacing: 16) {
                            StatTile(title: "This Week", value: "\(vm.workoutsThisWeek)", detail: "Workouts")
                            StatTile(title: "Streak", value: "\(vm.streakDays)", detail: "Days")
                        }

                        if let last = vm.lastWorkout {
                            HStack {
                                Image(systemName: "clock.arrow.circlepath")
                                Text("Last workout: \(last.formatted(date: .abbreviated, time: .shortened))")
                                Spacer()
                            }
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                        }

                        TrendCard(sessions: vm.sessions)

                        // History
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Recent Workouts").font(.title3.bold()).gradientForeground()
                            if vm.sessions.isEmpty {
                                VStack(spacing: 8) {
                                    Text("No workouts yet").font(.headline)
                                    Text("Start a session to see your progress.")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(24)
                                .glassCard(cornerRadius: 20)
                            } else {
                                ForEach(vm.sessions.prefix(12)) { session in
                                    WorkoutRow(session: session)
                                }
                            }
                        }
                    }
                    .padding(20)
                    .safeAreaPadding(.bottom, 160)
                }
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    AtlasNavigationTitle(title: "Progress", subtitle: "Track your streaks")
                }
            }
            .atlasNavigationBarStyle()
            .onAppear { vm.refresh() }
    }
}

// MARK: - Trend

private struct TrendCard: View {
    let sessions: [WorkoutSession]

    // Small model so Charts has an Identifiable element (tuples don't work with key paths)
    private struct DayCount: Identifiable {
        let date: Date
        let count: Int
        var id: Date { date }
    }

    var body: some View {
        let cal = Calendar(identifier: .gregorian)
        let today = cal.startOfDay(for: Date())
        let days = (0..<14).reversed().compactMap { cal.date(byAdding: .day, value: -$0, to: today) }
        let grouped = Dictionary(grouping: sessions) { cal.startOfDay(for: $0.date) }
        let data: [DayCount] = days.map { d in
            DayCount(date: d, count: grouped[d]?.count ?? 0)
        }

        VStack(alignment: .leading, spacing: 8) {
            Text("Last 14 days").font(.headline)
            Chart(data) { item in
                BarMark(x: .value("Day", item.date),
                        y: .value("Workouts", item.count))
            }
            .frame(height: 140)
        }
        .padding(12)
        .glassCard(cornerRadius: 16)
    }
}

// MARK: - Components

private struct StatTile: View {
    let title: String
    let value: String
    let detail: String
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.subheadline).foregroundStyle(.secondary)
            Text(value).font(.title).bold().gradientForeground()
            Text(detail).font(.footnote).foregroundStyle(.secondary)
        }
        .padding(16)
        .glassCard(cornerRadius: 20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct WorkoutRow: View {
    let session: WorkoutSession
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "figure.strengthtraining.traditional")
                .padding(10)
                .background(AtlasTheme.gradient.opacity(0.18), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(session.template).font(.headline)
                Text("\(session.date.formatted(date: .abbreviated, time: .shortened))")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(session.totalSets) sets").font(.subheadline)
                if let d = session.duration { Text(timeString(d)).font(.footnote).foregroundStyle(.secondary) }
            }
        }
        .padding(12)
        .glassCard(cornerRadius: 16)
    }

    private func timeString(_ t: TimeInterval) -> String {
        let mins = Int(t / 60)
        let secs = Int(t.truncatingRemainder(dividingBy: 60))
        return String(format: "%dm %02ds", mins, secs)
    }
}
