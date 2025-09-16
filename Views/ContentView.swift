//
//  ContentView.swift
//  AtlasFit
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
                                    accent: AtlasTheme.neon
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(.isButton)
                        }

                        NavigationLink {
                            WeeklyPlannerView()
                        } label: {
                            AtlasCard(
                                title: "Weekly Planner",
                                subtitle: "Map your week and auto-schedule reminders",
                                systemImage: "calendar",
                                accent: AtlasTheme.magenta
                            )
                        }
                        .buttonStyle(.plain)

                        // Dynamic tiles (now sourced from Progress)
                        HStack(spacing: 16) {
                            SummaryTile(title: "This Week",
                                        value: "\(progressVM.workoutsThisWeek) / \(weeklyGoal)",
                                        detail: "Workouts")
                            SummaryTile(title: "Streak",
                                        value: "\(progressVM.streakDays)",
                                        detail: progressVM.streakDays == 1 ? "Day" : "Days")
                        }

                        // Recent Workouts (mini)
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader(title: "Recent Workouts", subtitle: "Last 3 sessions")
                            if progressVM.sessions.isEmpty {
                                EmptyStateCard(title: "No workouts yet",
                                               subtitle: "Start a session to see your progress.")
                            } else {
                                ForEach(progressVM.sessions.prefix(3)) { session in
                                    MiniWorkoutRow(session: session)
                                }
                                NavigationLink {
                                    ProgressDashboardView()
                                } label: {
                                    Text("View all →").font(.subheadline.weight(.semibold))
                                }
                                .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                        }

                        // Quick Start Templates
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader(title: "Quick Start", subtitle: "Jump into a routine")
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(quickTemplates, id: \.self) { t in
                                        NavigationLink { StartWorkoutView() } label: {
                                            HStack(spacing: 8) {
                                                Image(systemName: "bolt.fill")
                                                Text(t)
                                            }
                                            .font(.subheadline.weight(.semibold))
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 10)
                                            .background(AtlasTheme.gradient.opacity(0.22), in: Capsule())
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }
            }
            .navigationTitle("AtlasFit")
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
                        Button("Reset Onboarding") {
                            DevReset.resetOnboarding()
                        }
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
        VStack(alignment: .leading, spacing: 12) {
            Text(greeting())
                .font(.largeTitle.bold())
                .gradientForeground()
                .opacity(appear ? 1 : 0)
                .offset(y: appear ? 0 : 8)
                .animation(.spring(duration: 0.6).delay(0.1), value: appear)

            Text("WORK HARDER TODAY · BE HEALTHIER TOMORROW")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .kerning(1)
                .opacity(appear ? 1 : 0)
                .offset(y: appear ? 0 : 6)
                .animation(.spring(duration: 0.6).delay(0.15), value: appear)

            HStack(spacing: 10) {
                NavigationLink { StartWorkoutView() } label: { Chip(text: "Start a Workout") }
                NavigationLink { WeeklyPlannerView() } label: { Chip(text: "Weekly Plan") }
                NavigationLink { ProgressDashboardView() } label: { Chip(text: "Progress") }
            }
            .buttonStyle(.plain)
            .opacity(appear ? 1 : 0)
            .offset(y: appear ? 0 : 8)
            .animation(.spring(duration: 0.6).delay(0.2), value: appear)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

// MARK: - Snapshot Card

private struct ProgressSnapshotCard: View {
    let workoutsThisWeek: Int
    let weeklyGoal: Int
    let streakDays: Int
    let lastWorkout: Date?
    let weekActivity: [Bool] // 7 flags, Sunday → Saturday

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "This Week", subtitle: "Work hard today → healthier tomorrow")

            HStack(spacing: 16) {
                SummaryTile(title: "Completed", value: "\(workoutsThisWeek) / \(weeklyGoal)", detail: "Workouts")
                SummaryTile(title: "Streak", value: "\(streakDays)", detail: streakDays == 1 ? "Day" : "Days")
            }

            WeekDots(flags: weekActivity)

            if let last = lastWorkout {
                HStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath")
                    Text("Last workout: \(last.formatted(date: .abbreviated, time: .shortened))")
                    Spacer()
                    NavigationLink { ProgressDashboardView() } label: {
                        Text("See progress →").font(.subheadline.weight(.semibold))
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 20)
    }
}

private struct WeekDots: View {
    let flags: [Bool] // Sunday → Saturday

    private var symbols: [String] {
        Calendar.current.shortWeekdaySymbols.map { String($0.prefix(1)) }
    }

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

// MARK: - Quick actions

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
            QuickActionPill(icon: "flame.fill", title: "Push Harder", detail: remainingDetail)
            QuickActionPill(icon: "target", title: "Hold the Line", detail: streakDetail)
            QuickActionPill(icon: "timer", title: "Last Grind", detail: lastWorkoutDetail)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct QuickActionPill: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(AtlasTheme.gradient)
                    .opacity(0.35)
                Circle()
                    .stroke(AtlasTheme.border, lineWidth: 1)
                Image(systemName: icon)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color.white)
            }
            .frame(width: 42, height: 42)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Text(detail)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: 260, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AtlasTheme.cardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AtlasTheme.border, lineWidth: 1)
        )
        .shadow(color: AtlasTheme.neon.opacity(0.18), radius: 10, x: 0, y: 6)
    }
}

// MARK: - Tiles & Rows

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
            .background(Capsule().fill(AtlasTheme.gradient.opacity(0.22)))
    }
}

#Preview { ContentView() }
