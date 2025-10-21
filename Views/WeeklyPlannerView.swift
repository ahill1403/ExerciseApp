import SwiftUI
import UserNotifications

struct WeeklyPlannerView: View {
    @State private var plan: WeeklyPlan = PlannerStore.shared.load()
    @State private var alertMessage: String?
    @State private var editorSelection: DaySelection?
    @State private var storedProfile: UserProfile? = WeeklyPlannerView.loadProfile()

    var body: some View {
        NavigationStack {
            ZStack { NeonMotionBackground() }
                .overlay(
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            SectionHeader(
                                title: "Weekly Planner",
                                subtitle: "Tap a day to review or adjust the workouts we’ve lined up for you"
                            )

                            WeekPlanGrid(plan: plan) { day in
                                editorSelection = DaySelection(day: day)
                            }

                            PlannerActions(
                                save: { PlannerStore.shared.save(plan) },
                                apply: applyReminders,
                                useRecommended: applyRecommendedPlan
                            )
                            .padding(.top, 8)
                        }
                        .padding(20)
                        .safeAreaPadding(.bottom, 160)
                    }
                )
                .navigationTitle("Plan")
        }
        .sheet(item: $editorSelection) { selection in
            DayPlanEditor(day: selection.day, plan: $plan, profile: storedProfile)
        }
        .onChange(of: plan) { _, newValue in
            PlannerStore.shared.save(newValue)
        }
        .alert(
            "Heads up",
            isPresented: Binding(get: { alertMessage != nil }, set: { if !$0 { alertMessage = nil } })
        ) {
            Button("OK", role: .cancel) { alertMessage = nil }
        } message: {
            Text(alertMessage ?? "")
        }
    }

    private struct DaySelection: Identifiable {
        let day: Int
        var id: Int { day }
    }

    static private func loadProfile() -> UserProfile? {
        guard
            let data = UserDefaults.standard.data(forKey: "userProfile"),
            let profile = try? JSONDecoder().decode(UserProfile.self, from: data)
        else { return nil }
        return profile
    }

    // MARK: - Scheduling

    func applyReminders() {
        let weekdays = PlannerStore.shared.selectedWeekdays(from: plan)
        guard !weekdays.isEmpty else {
            alertMessage = "Select at least one training day before applying reminders."
            return
        }

        guard
            let data = UserDefaults.standard.data(forKey: "userProfile"),
            let profile = try? JSONDecoder().decode(UserProfile.self, from: data),
            let time = profile.reminderTime
        else {
            alertMessage = "Enable reminders and pick a time in Edit Profile first."
            return
        }

        let center = UNUserNotificationCenter.current()
        let allIDs = ["atlasfit.dailyReminder"] + (1...7).map { "atlasfit.reminder.\($0)" }
        center.removePendingNotificationRequests(withIdentifiers: allIDs)

        let comps = Calendar.current.dateComponents([.hour, .minute], from: time)
        for wd in weekdays { // 1=Sun … 7=Sat
            var dc = DateComponents()
            dc.weekday = wd
            dc.hour    = comps.hour
            dc.minute  = comps.minute

            let content = UNMutableNotificationContent()
            content.title = "Time to train"
            content.body  = "Small steps today → big changes tomorrow."
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)
            let id = "atlasfit.reminder.\(wd)"
            center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
        }
        alertMessage = "Reminders scheduled for \(weekdays.count) day(s) per week."
    }

    func applyRecommendedPlan() {
        guard
            let data = UserDefaults.standard.data(forKey: "userProfile"),
            let profile = try? JSONDecoder().decode(UserProfile.self, from: data)
        else {
            alertMessage = "Complete onboarding to generate a recommended plan."
            return
        }

        let recommended = PlannerStore.shared.recommendedPlan(for: profile)
        plan = recommended
        storedProfile = profile
        PlannerStore.shared.save(recommended)
        alertMessage = "Weekly plan updated using your profile."
    }
}

// MARK: - Editor

private struct DayPlanEditor: View {
    let day: Int
    @Binding var plan: WeeklyPlan
    let profile: UserProfile?

    @Environment(\.dismiss) private var dismiss
    @State private var showWorkoutPicker = false

    private var dayName: String {
        let symbols = Calendar.current.weekdaySymbols
        let index = (day - 1 + symbols.count) % symbols.count
        return symbols[index]
    }

    private var workouts: [WorkoutDefinition] {
        WorkoutCatalog.shared.workouts(forIDs: plan.workoutIDs(for: day))
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Focus areas") {
                    ForEach(FitnessArea.allCases) { area in
                        Toggle(isOn: Binding(
                            get: { plan.focusAreas(for: day).contains(area) },
                            set: { isOn in
                                if isOn {
                                    plan.addFocus(area, to: day)
                                } else {
                                    plan.removeFocus(area, from: day)
                                }
                            }
                        )) {
                            Text(area.displayName)
                        }
                        .tint(AtlasTheme.accentGreen)
                    }
                }

                Section("Planned workouts") {
                    if workouts.isEmpty {
                        Text("No workouts yet. Add a few moves to shape this day.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(workouts) { workout in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(workout.name)
                                    .font(.headline)
                                Text(workout.summary)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(workout.equipment)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 2)
                            .swipeActions {
                                Button(role: .destructive) {
                                    plan.removeWorkout(workout.id, from: day)
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                            }
                        }
                    }

                    Button {
                        showWorkoutPicker = true
                    } label: {
                        Label("Add workout", systemImage: "plus.circle")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(dayName)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    if !plan.workoutIDs(for: day).isEmpty {
                        Button("Clear") {
                            plan.setWorkouts([], for: day)
                        }
                    }
                }
            }
            .sheet(isPresented: $showWorkoutPicker) {
                WorkoutPickerSheet(
                    day: day,
                    plan: $plan,
                    profile: profile,
                    presetAreas: plan.focusAreas(for: day)
                )
            }
        }
    }
}

// MARK: - Workout Picker

private struct WorkoutPickerSheet: View {
    let day: Int
    @Binding var plan: WeeklyPlan
    let profile: UserProfile?
    let presetAreas: [FitnessArea]

    @Environment(\.dismiss) private var dismiss
    @State private var selectedArea: FitnessArea?
    @State private var searchText: String = ""

    private var selectedIDs: Set<String> { Set(plan.workoutIDs(for: day)) }

    private var areaOptions: [FitnessArea] {
        let base = presetAreas.isEmpty ? FitnessArea.allCases : presetAreas
        return FitnessArea.allCases.filter { base.contains($0) }
    }

    private var workouts: [WorkoutDefinition] {
        let areas = selectedArea.map { [$0] } ?? areaOptions
        var unique: [WorkoutDefinition] = []
        var seen = Set<String>()
        for area in areas {
            let experience = profile?.experienceByArea[area] ?? profile?.experience ?? .novice
            let candidates = WorkoutCatalog.shared.allWorkouts(for: area, experience: experience)
            for workout in candidates {
                if seen.insert(workout.id).inserted {
                    unique.append(workout)
                }
            }
        }
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return unique.sorted { $0.name < $1.name }
        }
        let term = searchText.lowercased()
        return unique.filter { workout in
            workout.name.lowercased().contains(term) || workout.summary.lowercased().contains(term)
        }
        .sorted { $0.name < $1.name }
    }

    var body: some View {
        NavigationStack {
            List {
                if areaOptions.count > 1 {
                    Section("Filter by focus") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                FilterChip(title: "All", isSelected: selectedArea == nil) {
                                    selectedArea = nil
                                }
                                ForEach(areaOptions, id: \.self) { area in
                                    FilterChip(title: area.displayName, isSelected: selectedArea == area) {
                                        selectedArea = area
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                Section("Workouts") {
                    if workouts.isEmpty {
                        Text("No workouts match your filters just yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(workouts) { workout in
                            Button {
                                plan.addWorkout(workout.id, to: day)
                            } label: {
                                HStack(alignment: .top, spacing: 12) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(workout.name)
                                            .font(.headline)
                                        Text(workout.summary)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text(workout.equipment)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if selectedIDs.contains(workout.id) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(AtlasTheme.accentGreen)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Add workout")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
            .onAppear {
                if selectedArea == nil {
                    selectedArea = presetAreas.first
                }
            }
        }
    }
}

private struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(
                        isSelected ? AtlasTheme.gradient : AtlasTheme.cardFill
                    )
                )
                .foregroundStyle(isSelected ? Color.white : .secondary)
        }
        .buttonStyle(.plain)
    }
}

private struct PlannerActions: View {
    let save: () -> Void
    let apply: () -> Void
    let useRecommended: () -> Void

    var body: some View {
        ViewThatFits {
            HStack(spacing: 12) { buttons }
            VStack(spacing: 12) { buttons }
        }
    }

    @ViewBuilder
    private var buttons: some View {
        Button("Save Plan", action: save)
            .buttonStyle(AtlasButtonStyle())

        Button("Apply to Reminders", action: apply)
            .buttonStyle(AtlasButtonStyle(gradient: AtlasTheme.gradientAlt))

        Button("Use Recommended Plan", action: useRecommended)
            .buttonStyle(AtlasButtonStyle(gradient: AtlasTheme.gradient))
    }
}

#Preview { WeeklyPlannerView() }
