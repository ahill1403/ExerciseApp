//
//  StartWorkoutView.swift
//  AtlasFit
//
//  Created by Aaron Hill on 9/11/25.
//

import SwiftUI

struct StartWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = StartWorkoutViewModel()
    @State private var showFinishAlert = false

    // Inline edit state
    @State private var editExerciseID: UUID? = nil
    @State private var editSetIndex: Int? = nil
    @State private var editReps: Int = 8
    @State private var editWeight: Double = 0
    @State private var editUnits: Units = .lbs
    @State private var showEditSheet = false

    @State private var planSnapshot: WeeklyPlan = PlannerStore.shared.load()

    private let templateColumns: [GridItem] = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        ZStack {
            NeonMotionBackground()

            if !vm.isLogging {
                templatePicker
            } else {
                sessionLogger
            }
        }
        .navigationTitle("Start Workout")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            vm.refreshPlanSuggestion()
            planSnapshot = PlannerStore.shared.load()
        }
        .onReceive(vm.$planSuggestion.dropFirst()) { _ in
            planSnapshot = PlannerStore.shared.load()
        }
        .toolbar {
            if vm.isLogging {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { vm.reset(); dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Button("Autofill last") { vm.autofillFromLast() }
                        Button("Finish") { showFinishAlert = true }
                    }
                }
            }
        }
        .alert("Finish Workout?", isPresented: $showFinishAlert) {
            Button("Save", role: .none) { vm.finish(); dismiss() }
            Button("Keep Logging", role: .cancel) { }
        } message: { Text("Your session will be saved to Progress.") }
        .sheet(isPresented: $vm.showAddExercise) {
            AddExerciseSheet(name: $vm.newExerciseName) { vm.addExercise() }
        }
        .sheet(isPresented: $showEditSheet) {
            EditSetSheet(reps: $editReps, weight: $editWeight, units: $editUnits) {
                if let exID = editExerciseID,
                   let i = editSetIndex,
                   let idx = vm.exercises.firstIndex(where: { $0.id == exID }) {
                    vm.exercises[idx].sets[i] = SetEntry(reps: editReps, weight: editWeight, units: editUnits)
                }
            }
            .presentationDetents([.medium])
        }
    }

    // MARK: - Template Picker
    private var templatePicker: some View {
        ScrollView {
            VStack(spacing: 24) {
                planRecommendationSection
                templatesSection
                emptySessionSection
            }
            .padding(20)
        }
        .safeAreaPadding(.bottom, 160)
    }

    @ViewBuilder
    private var planRecommendationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("From your weekly planner", systemImage: "calendar")
                .font(.title3.bold())
                .gradientForeground()

            WeekSchedulePeek(plan: planSnapshot)

            if let suggestion = vm.planSuggestion,
               let firstTemplate = suggestion.templates.first,
               let templateInfo = vm.info(for: firstTemplate) {
                let dayName = weekdayName(for: suggestion.day)
                let focusSummary = suggestion.areas.map { $0.displayName }.joined(separator: " • ")

                VStack(alignment: .leading, spacing: 8) {
                    Text(suggestion.isToday ? "Today's recommendation" : (suggestion.offset == 1 ? "Tomorrow's recommendation" : "\(dayName)'s recommendation"))
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(focusSummary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 10) {
                    ForEach(suggestion.areas, id: \.self) { area in
                        Text(area.displayName)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(AtlasTheme.gradient.opacity(0.18), in: Capsule())
                    }
                    Spacer(minLength: 0)
                }

                Text("\(templateInfo.duration) • \(templateInfo.equipment)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(templateInfo.summary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Button {
                    vm.start(template: firstTemplate)
                } label: {
                    Label(suggestion.isToday ? "Start Today's Plan" : "Start \(dayName)", systemImage: "play.fill")
                }
                .buttonStyle(AtlasButtonStyle())

                if suggestion.templates.count > 1 {
                    Divider().opacity(0.12)

                    Text("Other planner-aligned options")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    VStack(spacing: 6) {
                        ForEach(Array(suggestion.templates.dropFirst()), id: \.self) { name in
                            Button {
                                vm.start(template: name)
                            } label: {
                                HStack {
                                    Image(systemName: "arrow.turn.down.right")
                                    Text(name)
                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(AtlasTheme.cardFill.opacity(0.6), in: RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            } else {
                Text("Set at least one training day in Weekly Planner to unlock a daily recommendation here.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text("Manage your schedule anytime from the Plan tab.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .glassCard(cornerRadius: 22)
    }

    private var templatesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Choose a template")
                .font(.title3.bold())
                .gradientForeground()

            Text("Curated sessions you can start in one tap.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: templateColumns, spacing: 14) {
                ForEach(vm.templates) { template in
                    Button {
                        vm.start(template: template.name)
                    } label: {
                        TemplateCard(template: template)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .glassCard(cornerRadius: 22)
    }

    private var emptySessionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Prefer to freestyle?")
                .font(.headline)
                .foregroundStyle(.primary)

            Text("Start an empty log and build the workout as you go.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Button("Start Empty Session") {
                vm.start(template: "Custom")
            }
            .buttonStyle(AtlasButtonStyle())
        }
        .padding(20)
        .glassCard(cornerRadius: 22)
    }

    private func weekdayName(for day: Int) -> String {
        let symbols = Calendar.current.weekdaySymbols
        let idx = (day - 1 + symbols.count) % symbols.count
        return symbols[idx]
    }

    // MARK: - Session Logger
    private var sessionLogger: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    sessionHeader
                    todaysPlanSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 160)
            }
        }
        .safeAreaInset(edge: .bottom) {
            loggingPanel
        }
    }

    private var currentWorkoutDefinition: WorkoutDefinition? {
        guard vm.currentWorkoutIndex >= 0, vm.currentWorkoutIndex < vm.todaysWorkouts.count else { return nil }
        return vm.todaysWorkouts[vm.currentWorkoutIndex]
    }

    private var currentExerciseEntry: ExerciseEntry? {
        guard let workout = currentWorkoutDefinition else { return nil }
        return vm.exercise(for: workout.id)
    }

    private var sessionHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text(vm.selectedTemplate ?? "Workout")
                    .font(.largeTitle.bold())
                    .foregroundStyle(AtlasTheme.textPrimary)

                Spacer()

                if let start = vm.startTime {
                    Text(start, style: .timer)
                        .monospacedDigit()
                        .font(.title3.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(AtlasTheme.gradient.opacity(0.18), in: Capsule())
                }
            }

            if let suggestion = vm.planSuggestion,
               suggestion.isToday,
               !suggestion.areas.isEmpty {
                Text(suggestion.areas.map { $0.displayName }.joined(separator: " • "))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            } else if let focus = currentWorkoutDefinition?.area.displayName {
                Text(focus)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Text("Keep momentum by logging each set below — it all feeds your progress trends.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .glassCard(cornerRadius: 26)
    }

    private var todaysPlanSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Today's plan")
                        .font(.title3.bold())
                        .foregroundStyle(AtlasTheme.textPrimary)

                    if let workout = currentWorkoutDefinition {
                        Text("Up next: \(workout.name)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if !vm.todaysWorkouts.isEmpty {
                    let completed = vm.completedWorkoutIDs.count
                    let total = vm.todaysWorkouts.count
                    Text("\(completed)/\(total) complete")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(AtlasTheme.gradient.opacity(0.14), in: Capsule())
                }
            }

            if vm.todaysWorkouts.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("No workouts planned today")
                        .font(.headline)
                        .foregroundStyle(AtlasTheme.textPrimary)

                    Text("Add a custom move to start logging, or schedule sessions from the Plan tab.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Button {
                        vm.showAddExercise = true
                    } label: {
                        Label("Add custom movement", systemImage: "plus")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(AtlasTheme.gradient.opacity(0.18), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(Array(vm.todaysWorkouts.enumerated()), id: \.element.id) { index, workout in
                        WorkoutProgressRow(
                            workout: workout,
                            isCurrent: index == vm.currentWorkoutIndex,
                            isCompleted: vm.isCompleted(workout.id),
                            onSelect: {
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                                    vm.selectWorkout(with: workout.id)
                                }
                            },
                            onToggleComplete: {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    vm.toggleCompletion(for: workout.id)
                                }
                            }
                        )
                    }
                }

                Text("Tap a card to focus logging on that workout. Check it off once you've completed the sets.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .glassCard(cornerRadius: 26)
    }

    private var loggingPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let workout = currentWorkoutDefinition,
               let exercise = currentExerciseEntry {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Log this workout")
                            .font(.headline)
                            .foregroundStyle(AtlasTheme.textPrimary)
                        Text(workout.name)
                            .font(.title3.bold())
                            .foregroundStyle(AtlasTheme.textPrimary)
                    }
                    Spacer()
                    if vm.completedWorkoutIDs.contains(workout.id) {
                        Label("Completed", systemImage: "checkmark.circle.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AtlasTheme.accentGreen)
                    }
                }

                Divider().opacity(0.15)

                if exercise.sets.isEmpty {
                    Text("No sets yet. Use the controls below to log your first set.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(spacing: 10) {
                        ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { index, set in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Set \(index + 1)")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(AtlasTheme.textPrimary)
                                    Text("\(set.reps) reps × \(set.weight, specifier: "%.0f") \(set.units.rawValue)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "slider.horizontal.3")
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(AtlasTheme.cardFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(AtlasTheme.border, lineWidth: 1)
                            )
                            .contextMenu {
                                Button("Edit") {
                                    editExerciseID = exercise.id
                                    editSetIndex = index
                                    editReps = set.reps
                                    editWeight = set.weight
                                    editUnits = set.units
                                    showEditSheet = true
                                }
                            }
                        }
                    }
                }

                AddSetInline { reps, weight, units in
                    vm.addSet(to: exercise.id, reps: reps, weight: weight, units: units)
                }
                .padding(.top, 4)
            } else if vm.todaysWorkouts.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Ready when you are")
                        .font(.headline)
                        .foregroundStyle(AtlasTheme.textPrimary)
                    Text("Add a movement above to start tracking reps, sets and load.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Select a workout above to begin logging reps, sets and weight.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if !vm.todaysWorkouts.isEmpty {
                Divider().opacity(0.08)

                Button {
                    vm.showAddExercise = true
                } label: {
                    Label("Add custom movement", systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(AtlasButtonStyle())
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(AtlasTheme.bgElevated.opacity(0.96))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(AtlasTheme.border, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.12), radius: 18, x: 0, y: 12)
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
    }

}

private struct TemplateCard: View {
    let template: StartWorkoutViewModel.TemplateInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(template.name)
                .font(.headline)
                .foregroundStyle(.primary)

            Text(template.focus)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(AtlasTheme.gradient.opacity(0.18), in: Capsule())

            Text("\(template.duration) • \(template.equipment)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(template.summary)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(3)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AtlasTheme.cardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AtlasTheme.border, lineWidth: 1)
        )
    }
}

private struct WorkoutProgressRow: View {
    let workout: WorkoutDefinition
    let isCurrent: Bool
    let isCompleted: Bool
    var onSelect: () -> Void
    var onToggleComplete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: onToggleComplete) {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(isCompleted ? AtlasTheme.accentGreen : .secondary)
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
            .opacity(isCurrent || isCompleted ? 1 : 0.35)
            .allowsHitTesting(isCurrent || isCompleted)

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text(workout.name)
                        .font(.headline)
                        .foregroundStyle(AtlasTheme.textPrimary)
                    Spacer()
                    if isCompleted {
                        Text("Done")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AtlasTheme.accentGreen)
                    } else if isCurrent {
                        Text("In progress")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AtlasTheme.accentGreen)
                    }
                }

                HStack(spacing: 8) {
                    Text(workout.area.displayName)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(AtlasTheme.gradient.opacity(0.18), in: Capsule())
                    Text(workout.equipment)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Text(workout.summary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(isCurrent ? AtlasTheme.gradient.opacity(0.22) : AtlasTheme.cardFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(isCurrent ? AtlasTheme.gradient : AtlasTheme.border, lineWidth: isCurrent ? 1.6 : 1)
            )
            .onTapGesture(perform: onSelect)
        }
        .padding(.vertical, 2)
        .opacity(isCompleted ? 0.55 : (isCurrent ? 1 : 0.82))
        .animation(.easeInOut(duration: 0.24), value: isCurrent)
        .animation(.easeInOut(duration: 0.24), value: isCompleted)
    }
}

private struct WeekSchedulePeek: View {
    let plan: WeeklyPlan

    private var calendar: Calendar {
        var cal = Calendar.current
        cal.firstWeekday = 1
        return cal
    }

    private var today: Int {
        Calendar.current.component(.weekday, from: Date())
    }

    var body: some View {
        HStack(spacing: 10) {
            ForEach(1...7, id: \.self) { day in
                let label = shortLabel(for: day)
                let hasFocus = !plan.focusAreas(for: day).isEmpty
                let isToday = day == today

                Text(label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(hasFocus ? Color.white : .secondary)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(hasFocus ? AtlasTheme.gradient : AtlasTheme.cardFill)
                    )
                    .overlay(
                        Circle()
                            .strokeBorder(isToday ? AtlasTheme.gradient : AtlasTheme.border, lineWidth: isToday ? 2 : 1)
                    )
                    .accessibilityLabel(accessibilityLabel(for: day, hasFocus: hasFocus))
            }
        }
    }

    private func shortLabel(for day: Int) -> String {
        let symbols = calendar.shortWeekdaySymbols
        let index = (day - 1 + symbols.count) % symbols.count
        return String(symbols[index].prefix(1))
    }

    private func accessibilityLabel(for day: Int, hasFocus: Bool) -> String {
        let name = calendar.weekdaySymbols[(day - 1 + calendar.weekdaySymbols.count) % calendar.weekdaySymbols.count]
        var components = [name]
        components.append(hasFocus ? "training day" : "rest day")
        if day == today { components.append("today") }
        return components.joined(separator: ", ")
    }
}

// MARK: - Components

private struct AddExerciseSheet: View {
    @Binding var name: String
    var onAdd: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Exercise Name") {
                    TextField("e.g., Bench Press", text: $name)
                }
            }
            .navigationTitle("Add Exercise")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") {
                        onAdd()
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

private struct AddSetInline: View {
    @State private var reps: Int = 8
    @State private var weight: Double = 100
    @State private var units: Units = .lbs
    var onAdd: (_ reps: Int, _ weight: Double, _ units: Units) -> Void

    var body: some View {
        HStack(spacing: 12) {
            Stepper("Reps: \(reps)", value: $reps, in: 1...50)
            Spacer()
            TextField("Weight", value: $weight, format: .number)
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
                .frame(width: 90)
            Picker("", selection: $units) {
                ForEach(Units.allCases) { Text($0.rawValue).tag($0) }
            }
            .frame(width: 80)
            Button {
                onAdd(reps, weight, units)
            } label: {
                Image(systemName: "plus.circle.fill").font(.title3)
            }
        }
    }
}

private struct EditSetSheet: View {
    @Binding var reps: Int
    @Binding var weight: Double
    @Binding var units: Units
    let onSave: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Stepper("Reps: \(reps)", value: $reps, in: 1...100)
                HStack {
                    Text("Weight")
                    Spacer()
                    TextField("0", value: $weight, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 100)
                    Picker("", selection: $units) {
                        ForEach(Units.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .frame(width: 90)
                }
            }
            .navigationTitle("Edit Set")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Save", action: onSave)
                }
            }
        }
    }
}

#Preview("Light") { AtlasTabRoot().preferredColorScheme(.light) }
#Preview("Dark")  { AtlasTabRoot().preferredColorScheme(.dark) }
