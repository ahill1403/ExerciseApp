//
//  ProgressDashboardView.swift
//  AtlasFit
//
//  Created by Aaron Hill on 9/11/25.
//

import SwiftUI

struct ProgressDashboardView: View {
    @StateObject private var vm = ProgressViewModel()

    var body: some View {
        ZStack {
            NeonMotionBackground()

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
            }
        }
        .navigationTitle("Progress")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { vm.refresh() }
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
                .background(AtlasTheme.gradient.opacity(0.25), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(session.template).font(.headline)
                Text("\(session.date.formatted(date: .abbreviated, time: .shortened))")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(session.totalSets) sets").font(.subheadline)
                if let d = session.duration {
                    Text(timeString(d)).font(.footnote).foregroundStyle(.secondary)
                }
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
