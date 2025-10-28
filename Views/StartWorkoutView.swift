//
//  StartWorkoutView.swift
//  REPS
//
//  Created by Aaron Hill on 9/11/25.
//

import SwiftUI

private enum ActiveSheet: Identifiable {
    case addExercise
    case editSet
    case manageSets

    var id: String {
        switch self {
        case .addExercise: return "addExercise"
        case .editSet:     return "editSet"
        case .manageSets:  return "manageSets"
        }
    }
}

struct StartWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var vm = StartWorkoutViewModel()
    @State private var showFinishAlert = false
    var onLoggingStateChange: (Bool) -> Void = { _ in }

    // Inline edit state
    @State private var editExerciseID: UUID? = nil
    @State private var editSetIndex: Int? = nil
    @State private var editReps: Int = 8
    @State private var editWeight: Double = 0
    @State private var editUnits: Units = .lbs

    // Unified sheet controller
    @State private var activeSheet: ActiveSheet?

    @State private var planSnapshot: WeeklyPlan = PlannerStore.shared.load()
    @State private var expandedTemplateID: StartWorkoutViewModel.TemplateInfo.ID?
    @State private var showAllTemplates = false

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
            onLoggingStateChange(vm.isLogging)
        }
        // iOS 17: zero-parameter onChange; observe Equatable projection (Int?)
        .onChange(of: vm.planSuggestion?.day) {
            planSnapshot = PlannerStore.shared.load()
        }
        .onChange(of: vm.isLogging) {
            let isLogging = vm.isLogging
            onLoggingStateChange(isLogging)
            if isLogging {
                expandedTemplateID = nil
                showAllTemplates = false
            }
        }
        // Keep toolbar items structurally present; gate content inside
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if vm.isLogging {
                    Button("Cancel") { vm.reset(); dismiss() }
                } else {
                    EmptyView()
                }
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                if vm.isLogging {
                    Button("Autofill last") { vm.autofillFromLast() }
                    Button("Finish") { showFinishAlert = true }
                } else {
                    EmptyView()
                }
            }
        }
        .alert("Finish Workout?", isPresented: $showFinishAlert) {
            Button("Save") { vm.finish(); dismiss() }
            Button("Keep Logging", role: .cancel) { }
        } message: {
            Text("Your session will be saved to Progress.")
        }
        .sheet(item: $activeSheet) { sheet in
            sheetContent(for: sheet)
        }
        .onDisappear {
            onLoggingStateChange(false)
        }
    }

    // MARK: - Sheet content helper
    @ViewBuilder
    private func sheetContent(for sheet: ActiveSheet) -> some View {
        switch sheet {
        case .addExercise:
            AddExerciseSheet(name: $vm.newExerciseName) {
                vm.addExercise()
            }
        case .editSet:
            EditSetSheet(reps: $editReps, weight: $editWeight, units: $editUnits) {
                if let exID = editExerciseID,
                   let i = editSetIndex,
                   let idx = vm.exercises.firstIndex(where: { $0.id == exID }) {
                    vm.exercises[idx].sets[i] = SetEntry(reps: editReps, weight: editWeight, units: editUnits)
                }
            }
            .presentationDetents([.medium])
        case .manageSets:
            if let workout = currentWorkoutDefinition,
               let exercise = currentExerciseEntry {
                ManageSetsSheet(
                    workout: workout,
                    exercise: exercise,
                    onSelectSet: { index, set in
                        editExerciseID = exercise.id
                        editSetIndex = index
                        editReps = set.reps
                        editWeight = set.weight
                        editUnits = set.units
                        activeSheet = .editSet
                    }
                )
                .presentationDetents([.medium, .large])
            } else {
                Text("No sets to manage right now.")
                    .padding()
            }
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
                .font(.title2.bold())
                .gradientForeground()

            WeekSchedulePeek(plan: planSnapshot)

            if let suggestion = vm.planSuggestion,
               let firstTemplate = suggestion.templates.first,
               let templateInfo = vm.info(for: firstTemplate) {

                let dayName = weekdayName(for: suggestion.day)
                let focusSummary = suggestion.areas.map { $0.displayName }.joined(separator: " • ")

                VStack(alignment: .leading, spacing: 8) {
                    // FIX 1: compute header as a single expression so ViewBuilder doesn't see naked statements
                    let header = suggestion.isToday
                    ? "Today's recommendation"
                    : (suggestion.offset == 1 ? "Tomorrow's recommendation" : "\(dayName)'s recommendation")

                    Text(header)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(focusSummary)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
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
                    .foregroundColor(.secondary)

                Text(templateInfo.summary)
                    .font(.footnote)
                    .foregroundColor(.secondary)

                Button {
                    vm.start(template: firstTemplate)
                    expandedTemplateID = nil
                } label: {
                    Label(suggestion.isToday ? "Start Today's Plan" : "Start \(dayName)", systemImage: "play.fill")
                }
                .buttonStyle(AtlasButtonStyle())

                if suggestion.templates.count > 1 {
                    Divider().opacity(0.12)

                    Text("Other planner-aligned options")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)

                    VStack(spacing: 6) {
                        ForEach(Array(suggestion.templates.dropFirst()), id: \.self) { name in
                            Button {
                                vm.start(template: name)
                                expandedTemplateID = nil
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
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text("Manage your schedule anytime from the Plan tab.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(20)
        .glassCard(cornerRadius: 22)
    }

    private var templatesSection: some View {
        VStack(alignment: .center, spacing: 12) {
            Text("Choose a template")
                .font(.title2.bold())
                .gradientForeground()
                .padding(.top, 15)

            Text("Curated sessions you can start in one tap.")
                .font(.footnote)
                .foregroundColor(.secondary)
                .padding(.bottom, 2)

            let templatesToShow = showAllTemplates ? vm.templates : Array(vm.templates.prefix(2))

            LazyVGrid(columns: templateColumns, spacing: 14) {
                ForEach(templatesToShow) { template in
                    let isExpanded = expandedTemplateID == template.id
                    TemplateCard(
                        template: template,
                        isExpanded: isExpanded,
                        onToggle: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                expandedTemplateID = isExpanded ? nil : template.id
                            }
                        },
                        onStart: {
                            vm.start(template: template.name)
                            expandedTemplateID = nil
                        }
                    )
                }
            }
            .animation(.easeInOut(duration: 0.2), value: expandedTemplateID)

            if vm.templates.count > 2 {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showAllTemplates.toggle()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text(showAllTemplates ? "Show fewer" : "More templates")
                            .font(.subheadline.weight(.semibold))
                        Image(systemName: showAllTemplates ? "chevron.up" : "chevron.down")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(AtlasTheme.cardFill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(AtlasTheme.border, lineWidth: 1)
                )
            }
        }
        .glassCard(cornerRadius: 22)
    }

    private var emptySessionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Prefer to freestyle?")
                .font(.headline)
                .foregroundColor(.primary)

            Text("Start an empty log and build the workout as you go.")
                .font(.footnote)
                .foregroundColor(.secondary)

            Button("Start Empty Session") {
                vm.start(template: "Custom")
                expandedTemplateID = nil
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
                .padding(.bottom, 120)
            }
        }
        .safeAreaInset(edge: .bottom) {
            LoggingPanel(
                vm: vm,
                currentWorkoutDefinition: currentWorkoutDefinition,
                currentExerciseEntry: currentExerciseEntry,
                editExerciseID: $editExerciseID,
                editSetIndex: $editSetIndex,
                editReps: $editReps,
                editWeight: $editWeight,
                editUnits: $editUnits,
                activeSheet: $activeSheet
            )
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
                    .foregroundColor(AtlasTheme.textPrimary)

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
                    .foregroundColor(.secondary)
            } else if let focus = currentWorkoutDefinition?.area.displayName {
                Text(focus)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.secondary)
            }

            Text("Keep momentum by logging each set below — it all feeds your progress trends.")
                .font(.footnote)
                .foregroundColor(.secondary)
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
                        .foregroundColor(AtlasTheme.textPrimary)

                    if let workout = currentWorkoutDefinition {
                        Text("Up next: \(workout.name)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                if !vm.todaysWorkouts.isEmpty {
                    let completed = vm.completedWorkoutIDs.count
                    let total = vm.todaysWorkouts.count
                    Text("\(completed)/\(total) complete")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(AtlasTheme.gradient.opacity(0.14), in: Capsule())
                }
            }

            if vm.todaysWorkouts.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("No workouts planned today")
                        .font(.headline)
                        .foregroundColor(AtlasTheme.textPrimary)

                    Text("Add a custom move to start logging, or schedule sessions from the Plan tab.")
                        .font(.footnote)
                        .foregroundColor(.secondary)

                    Button {
                        activeSheet = .addExercise
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
                    ForEach(Array(vm.todaysWorkouts.enumerated()), id: \.offset) { index, workout in
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
                    .foregroundColor(.secondary)

                if let exercise = currentExerciseEntry,
                   !exercise.sets.isEmpty {
                    Button {
                        activeSheet = .manageSets
                    } label: {
                        Text("View and edit sets")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(AtlasButtonStyle())
                    .padding(.top, 8)
                }
            }
        }
        .padding(24)
        .glassCard(cornerRadius: 26)
    }
}

// MARK: - Extracted Logging Panel
private struct LoggingPanel: View {
    @ObservedObject var vm: StartWorkoutViewModel
    let currentWorkoutDefinition: WorkoutDefinition?
    let currentExerciseEntry: ExerciseEntry?

    @Binding var editExerciseID: UUID?
    @Binding var editSetIndex: Int?
    @Binding var editReps: Int
    @Binding var editWeight: Double
    @Binding var editUnits: Units
    @Binding var activeSheet: ActiveSheet?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Capsule()
                .fill(Color.white.opacity(0.3))
                .frame(width: 40, height: 5)
                .frame(maxWidth: .infinity)

            if let workout = currentWorkoutDefinition,
               let exercise = currentExerciseEntry {
                header(workout: workout)

                if exercise.sets.isEmpty {
                    Text("No sets yet. Use the controls below to log your first set.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                } else {
                    Text("Use the button above to review or edit your logged sets.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Divider().opacity(0.08)

                AddSetInline { reps, weight, units in
                    vm.addSet(to: exercise.id, reps: reps, weight: weight, units: units)
                }
                .padding(.top, 4)

            } else if vm.todaysWorkouts.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Ready when you are")
                        .font(.headline)
                        .foregroundColor(AtlasTheme.textPrimary)
                    Text("Add a movement above to start tracking reps, sets and load.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            } else {
                Text("Select a workout above to begin logging reps, sets and weight.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }

            if !vm.todaysWorkouts.isEmpty {
                Divider().opacity(0.08)

                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Need something else?")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(AtlasTheme.textPrimary)

                        Text("Log a move that's not in today's plan.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer(minLength: 0)

                    Button {
                        activeSheet = .addExercise
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(AtlasTheme.gradient)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Add custom movement")
                    .accessibilityHint("Opens a sheet to log your own exercise")
                }
            }
        }
        .padding(.top, 12)
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            UnevenRoundedRectangle(
                cornerRadii: .init(topLeading: 28, bottomLeading: 0, bottomTrailing: 0, topTrailing: 28 )
            )
            .fill(AtlasTheme.bgElevated.opacity(0.96))
        )
        .overlay(
            UnevenRoundedRectangle(
                cornerRadii: .init(topLeading: 28, bottomLeading: 0, bottomTrailing: 0, topTrailing: 28)
            )
            .stroke(AtlasTheme.border, lineWidth: 1)
        )

        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
                .padding(.horizontal, 12)
        }
        .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: -2)
        .ignoresSafeArea(edges: .bottom)
    }

    @ViewBuilder
    private func header(workout: WorkoutDefinition) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Log this workout")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.secondary)

                    Text(workout.name)
                        .font(.title3.bold())
                        .foregroundColor(AtlasTheme.textPrimary)
                }

                Spacer(minLength: 0)

                if vm.completedWorkoutIDs.contains(workout.id) {
                    Label("Completed", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(AtlasTheme.accentGreen)
                }
            }

            Text(workout.area.displayName)
                .font(.caption.weight(.semibold))
                .foregroundColor(.secondary)
        }
    }

}

private struct ManageSetsSheet: View {
    let workout: WorkoutDefinition
    let exercise: ExerciseEntry
    var onSelectSet: (Int, SetEntry) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(workout.name)
                            .font(.title3.bold())
                            .foregroundColor(AtlasTheme.textPrimary)

                        Text(exercise.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.secondary)

                        Text("Tap a set below to make quick edits.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if exercise.sets.isEmpty {
                        Text("No sets logged yet — add one from the logger below.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    } else {
                        VStack(spacing: 12) {
                            ForEach(Array(exercise.sets.enumerated()), id: \.offset) { index, set in
                                Button {
                                    onSelectSet(index, set)
                                } label: {
                                    HStack(alignment: .center, spacing: 16) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Set \(index + 1)")
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundColor(AtlasTheme.textPrimary)

                                            Text("\(set.reps) reps × \(set.weight, specifier: "%.0f") \(set.units.rawValue)")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }

                                        Spacer(minLength: 0)

                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.horizontal, 18)
                                    .padding(.vertical, 14)
                                    .background(AtlasTheme.cardFill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                                            .stroke(AtlasTheme.border, lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(24)
            }
            .background(AtlasTheme.bgBase)
            .navigationTitle("Sets")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Small components

private struct TemplateCard: View {
    let template: StartWorkoutViewModel.TemplateInfo
    let isExpanded: Bool
    let onToggle: () -> Void
    let onStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: isExpanded ? 14 : 8) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(template.name)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(template.duration)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer(minLength: 0)

                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onToggle)

            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    Text(template.focus)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(AtlasTheme.gradient.opacity(0.18), in: Capsule())

                    Label(template.equipment, systemImage: "dumbbell.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(template.summary)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Button {
                        onStart()
                    } label: {
                        Label("Start workout", systemImage: "play.fill")
                    }
                    .buttonStyle(AtlasButtonStyle())
                    .padding(.top, 2)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
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
        let showDone = isCompleted
        let showInProgress = (!isCompleted && isCurrent)
        let rowOpacity: Double = isCompleted ? 0.6 : 1.0

        // Normalize styles up front (same concrete type via AnyShapeStyle)
        let fillStyle: AnyShapeStyle = isCurrent
            ? AnyShapeStyle(AtlasTheme.gradient.opacity(0.18))
            : AnyShapeStyle(AtlasTheme.cardFill)

        let strokeStyle: AnyShapeStyle = isCurrent
            ? AnyShapeStyle(AtlasTheme.gradient)
            : AnyShapeStyle(AtlasTheme.border)

        let strokeWidth: CGFloat = isCurrent ? 1.2 : 1.0
        let statusText: String? = showDone ? "Done" : (showInProgress ? "In progress" : nil)

        HStack(alignment: .center, spacing: 12) {
            // Checkbox
            Image(systemName: showDone ? "checkmark.circle.fill" : "circle")
                .font(.title2.weight(.semibold))
                .foregroundColor(showDone ? AtlasTheme.accentGreen : .secondary)
                .frame(width: 34, height: 34)
                .onTapGesture(perform: onToggleComplete)

            // Text content
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text(workout.name)
                        .font(.headline)
                        .foregroundColor(AtlasTheme.textPrimary)
                    Spacer()
                    if let status = statusText {
                        Text(status)
                            .font(.caption.weight(.semibold))
                            .foregroundColor(AtlasTheme.accentGreen)
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
                        .foregroundColor(.secondary)
                }

                Text(workout.summary)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(fillStyle)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(strokeStyle, lineWidth: strokeWidth)
            )
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .opacity(rowOpacity)
        .accessibilityAddTraits(.isButton)
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
                    .foregroundColor(hasFocus ? .white : .secondary)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(hasFocus ? AtlasTheme.gradient : AtlasTheme.cardFill)
                    )
                    .overlay(
                        Circle()
                            // FIX 3: make both branches the same type via AnyShapeStyle
                            .strokeBorder(
                                (isToday ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(AtlasTheme.border)),
                                lineWidth: isToday ? 2 : 1
                            )
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
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick log")
                .font(.footnote.weight(.semibold))
                .foregroundColor(.secondary)

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .bottom, spacing: 12) {
                    CompactIntAdjuster(title: "Reps", value: $reps, range: 1...50)

                    CompactDoubleAdjuster(title: "Weight", value: $weight, step: 5)

                    Picker("Units", selection: $units) {
                        ForEach(Units.allCases, id: \.self) { unit in
                            Text(unit.rawValue).tag(unit)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 140)

                    logButton
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        CompactIntAdjuster(title: "Reps", value: $reps, range: 1...50)
                        CompactDoubleAdjuster(title: "Weight", value: $weight, step: 5)
                    }

                    HStack(spacing: 12) {
                        Picker("Units", selection: $units) {
                            ForEach(Units.allCases, id: \.self) { unit in
                                Text(unit.rawValue).tag(unit)
                            }
                        }
                        .pickerStyle(.segmented)

                        logButton
                    }
                }
            }
        }
    }

    private var logButton: some View {
        Button {
            onAdd(reps, weight, units)
        } label: {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white)
                .padding(10)
                .background(
                    Circle()
                        .fill(AtlasTheme.gradient)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Log set")
    }
}

private struct CompactIntAdjuster: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    var step: Int = 1

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundColor(.secondary)

            HStack(spacing: 0) {
                StepButton(systemName: "minus") {
                    value = max(range.lowerBound, value - step)
                }

                Text("\(value)")
                    .font(.title3.bold())
                    .frame(minWidth: 54)
                    .multilineTextAlignment(.center)
                    .foregroundColor(AtlasTheme.textPrimary)

                StepButton(systemName: "plus") {
                    value = min(range.upperBound, value + step)
                }
            }
            .background(AtlasTheme.cardFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(AtlasTheme.border, lineWidth: 1)
            )
        }
    }
}

private struct CompactDoubleAdjuster: View {
    let title: String
    @Binding var value: Double
    var step: Double = 2.5

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundColor(.secondary)

            HStack(spacing: 0) {
                StepButton(systemName: "minus") {
                    value = max(0, value - step)
                }

                Text(value.formatted(.number.precision(.fractionLength(0))))
                    .font(.title3.bold())
                    .frame(minWidth: 64)
                    .multilineTextAlignment(.center)
                    .foregroundColor(AtlasTheme.textPrimary)

                StepButton(systemName: "plus") {
                    value += step
                }
            }
            .background(AtlasTheme.cardFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(AtlasTheme.border, lineWidth: 1)
            )
        }
    }
}

private struct StepButton: View {
    let systemName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
                        ForEach(Units.allCases, id: \.self) { unit in
                            Text(unit.rawValue).tag(unit)
                        }
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

// NOTE: Move previews to StartWorkoutView_Previews.swift to keep this file lean.
#Preview("Light") { AtlasTabRoot().preferredColorScheme(.light) }
#Preview("Dark")  { AtlasTabRoot().preferredColorScheme(.dark) }
