//
//  ContentView.swift
//  REPS
//

import SwiftUI

struct ContentView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("weeklyGoal") private var weeklyGoal: Int = 5

    @State private var showOnboardingSheet = false
    @StateObject private var progressVM = ProgressViewModel()

    private let quickTemplates = ["Full Body", "Upper Body", "Lower Body", "Push", "Pull", "Legs", "Core", "Custom"]

    var body: some View {
        NavigationStack {
            ZStack {
                NeonMotionBackground()

                ScrollView {
                    VStack(spacing: 24) {
                        HeroHeader()

                        // Snapshot / Stats
                        ProgressSnapshotCard(
                            workoutsThisWeek: progressVM.workoutsThisWeek,
                            weeklyGoal: weeklyGoal,
                            streakDays: progressVM.streakDays,
                            lastWorkout: progressVM.lastWorkout,
                            weekActivity: weekActivity()
                        )

                        QuickActions(
                            remaining: max(weeklyGoal - progressVM.workoutsThisWeek, 0),
                            streak: progressVM.streakDays,
                            lastWorkout: progressVM.lastWorkout
                        )

                        if !hasCompletedOnboarding {
                            Button {
                                showOnboardingSheet = true
                            } label: {
                                AtlasCard(
                                    title: "Finish Setup",
                                    subtitle: "Tell us your goals and schedule",
                                    systemImage: "person.badge.plus",
                                    accent: AtlasTheme.accentGreen
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(.isButton)
                        }

                        // Recent Workouts (mini)
                        VStack(spacing: 12) {
                            // ⬇️ Centered header
                            VStack(spacing: 4) {
                                Text("Recent Workouts")
                                    .font(.title.bold())
                                    .foregroundStyle(.primary )
                                Text("Last 3 sessions")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)

                            if progressVM.sessions.isEmpty {
                                EmptyStateCard(title: "No workouts yet",
                                               subtitle: "Start a session to see your progress.")
                            } else {
                                ForEach(progressVM.sessions.prefix(3)) { session in
                                    MiniWorkoutRow(session: session)
                                }
                                // "View all" link intentionally removed
                            }
                        }

                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                    .safeAreaPadding(.bottom, 120)
                }
            }
            .navigationTitle("REPS")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Profile button (top-left) → Edit Profile
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink { EditProfileView() } label: {
                        Image(systemName: "person.crop.circle")
                            .imageScale(.large)
                    }
                }

                #if DEBUG
                // Dev menu (top-right)
                ToolbarItem(placement: .topBarTrailing) {
                    Menu("Dev") {
                        Button("Reset Onboarding") { DevReset.resetOnboarding() }
                    }
                }
                #endif
            }
            .onAppear { progressVM.refresh() }
        }
        .sheet(isPresented: $showOnboardingSheet) {
            OnboardingFlowView()
        }
    }

    // MARK: - Week Activity (Sunday → Saturday for current week)
    private func weekActivity() -> [Bool] {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale.current
        cal.firstWeekday = 1 // Sunday

        let all = WorkoutStore.shared.load()
        let byDay = Set(all.map { cal.startOfDay(for: $0.date) })

        let today = Date()
        let weekday = cal.component(.weekday, from: today) // 1=Sun ... 7=Sat
        let daysFromSunday = weekday - 1
        let startOfThisWeek = cal.startOfDay(for: cal.date(byAdding: .day, value: -daysFromSunday, to: today)!)

        var flags: [Bool] = []
        for i in 0..<7 {
            if let d = cal.date(byAdding: .day, value: i, to: startOfThisWeek) {
                flags.append(byDay.contains(cal.startOfDay(for: d)))
            }
        }
        return flags
    }
}

// MARK: - Header

private struct HeroHeader: View {
    @State private var appear = false

    var body: some View {
        VStack(spacing: 12) {
            Text(greeting())
                .font(.largeTitle.bold())
                .foregroundStyle(.primary )
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)         // center horizontally
                .opacity(appear ? 1 : 0)
                .offset(y: appear ? 0 : 8)
                .animation(.spring(duration: 0.6).delay(0.1), value: appear)

            Text("WORK HARDER TODAY · BE HEALTHIER TOMORROW")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .kerning(1)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)         // center horizontally
                .opacity(appear ? 1 : 0)
                .offset(y: appear ? 0 : 6)
                .animation(.spring(duration: 0.6).delay(0.15), value: appear)

            // no chips here (tabs handle nav)
        }
        .onAppear { appear = true }
    }

    private func greeting() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default: return "Welcome back"
        }
    }
}

// MARK: - Snapshot Card (centered)

private struct ProgressSnapshotCard: View {
    let workoutsThisWeek: Int
    let weeklyGoal: Int
    let streakDays: Int
    let lastWorkout: Date?
    let weekActivity: [Bool]

    var body: some View {
        VStack(spacing: 16) {
            // Centered header
            VStack(spacing: 4) {
                Text("This Week")
                    .font(.title.bold())
                    .gradientForeground()
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)

            // Centered tiles
            HStack(spacing: 16) {
                CenteredSummaryTile(title: "Completed", value: "\(workoutsThisWeek) / \(weeklyGoal)", detail: "Workouts")
                CenteredSummaryTile(title: "Streak", value: "\(streakDays)", detail: streakDays == 1 ? "Day" : "Days")
            }
            .frame(maxWidth: .infinity)

            // Centered week dots
            WeekDots(flags: weekActivity)
                .frame(maxWidth: .infinity, alignment: .center)

            // Centered "last workout" line
            if let last = lastWorkout {
                HStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath")
                    Text("Last workout: \(last.formatted(date: .abbreviated, time: .shortened))")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 20)
    }
}

private struct CenteredSummaryTile: View {
    let title: String
    let value: String
    let detail: String

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title)
                .bold()
                .gradientForeground()
            Text(detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(16)
        .glassCard(cornerRadius: 20)
    }
}


private struct WeekDots: View {
    let flags: [Bool]
    private var symbols: [String] { Calendar.current.shortWeekdaySymbols.map { String($0.prefix(1)) } }

    var body: some View {
        HStack(spacing: 10) {
            ForEach(Array(flags.enumerated()), id: \.offset) { idx, on in
                VStack(spacing: 6) {
                    Circle()
                        .fill(on
                              ? AtlasTheme.gradient
                              : LinearGradient(colors: [.secondary.opacity(0.3), .secondary.opacity(0.2)],
                                               startPoint: .top, endPoint: .bottom))
                        .frame(width: 16, height: 16)
                        .overlay(Circle().strokeBorder(.white.opacity(0.12)))
                    Text(symbols[idx])
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct QuickActions: View {
    let remaining: Int
    let streak: Int
    let lastWorkout: Date?

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    private var remainingDetail: String {
        switch remaining {
        case ...0: return "Goal met • stack extra work"
        case 1: return "1 session left • finish strong"
        default: return "\(remaining) sessions left • no excuses"
        }
    }

    private var streakDetail: String {
        switch streak {
        case ..<1: return "Streak starts now"
        case 1: return "1 day on • build momentum"
        default: return "\(streak) days on • keep the chain"
        }
    }

    private var lastWorkoutDetail: String {
        guard let lastWorkout else { return "No sessions yet • time to move" }
        let relative = QuickActions.relativeFormatter.localizedString(for: lastWorkout, relativeTo: Date())
        return "\(relative) • stay relentless"
    }

    var body: some View {
        Wrap(spacing: 12) {
            // optional quick action pills (kept hidden to avoid duplication)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SummaryTile: View {
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

private struct MiniWorkoutRow: View {
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

private struct EmptyStateCard: View {
    let title: String
    let subtitle: String
    var body: some View {
        VStack(spacing: 8) {
            Text(title).font(.headline)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .glassCard(cornerRadius: 20)
    }
}

private struct Chip: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(AtlasTheme.gradient.opacity(0.18)))
    }
}

#Preview { ContentView() }
#Preview { AtlasTabRoot() }
