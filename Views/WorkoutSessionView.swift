//
//  WorkoutSessionView.swift
//  REPS
//
//  Created by Aaron Hill on 10/28/25.
//

import SwiftUI
import UIKit

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

struct WorkoutSessionView: View {
    @ObservedObject var vm: StartWorkoutViewModel
    
    // Inline edit state
    @State private var editExerciseID: UUID? = nil
    @State private var editSetIndex: Int? = nil
    @State private var editReps: Int = 8
    @State private var editWeight: Double = 0
    @State private var editUnits: Units = .lbs
    
    // Unified sheet controller
    @State private var activeSheet: ActiveSheet?
    @State private var showFinishAlert = false
    @State private var showSetManagerCard = false
    @State private var restEndDate: Date? = nil
    @State private var restStartDate: Date? = nil
    
    private let setCardAnimation = Animation.spring(response: 0.32, dampingFraction: 0.82)
    private let defaultRestDuration: TimeInterval = 90
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                sessionHeader
                todaysPlanSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 80)
        }
        .ignoresSafeArea(edges: .bottom)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if vm.isLogging {
                    Button("Cancel") { vm.reset() }
                }
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                if vm.isLogging {
                    Button("Finish") { showFinishAlert = true }
                }
            }
        }
        .atlasNavigationBarStyle()
        .alert("Finish Workout?", isPresented: $showFinishAlert) {
            Button("Save") { vm.finish() }
            Button("Keep Logging", role: .cancel) { }
        } message: {
            Text("Your session will be saved to Progress.")
        }
        .sheet(item: $activeSheet) { sheet in
            sheetContent(for: sheet)
        }
        .onAppear {
            showSetManagerCard = (currentExerciseEntry?.sets.isEmpty == false)
        }
        .onChange(of: currentExerciseEntry?.id) { _, _ in
            withAnimation(setCardAnimation) {
                showSetManagerCard = (currentExerciseEntry?.sets.isEmpty == false)
            }
        }
        .onChange(of: currentExerciseEntry?.sets.count ?? 0) { _, newValue in
            withAnimation(setCardAnimation) {
                showSetManagerCard = newValue > 0
            }
        }
        .onChange(of: vm.isLogging) { _, isLogging in
            if !isLogging {
                restEndDate = nil
                restStartDate = nil
            }
        }
        .overlay {
            if let endDate = restEndDate, let startDate = restStartDate {
                RestTimerOverlay(
                    startDate: startDate,
                    endDate: endDate,
                    duration: defaultRestDuration,
                    onCancel: { elapsed in
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                            restEndDate = nil
                            restStartDate = nil
                        }
                        vm.recordRestDuration(elapsed)
                    },
                    onReachedZero: {
                        UINotificationFeedbackGenerator().notificationOccurred(.warning)
                    }
                )
                .transition(.opacity.combined(with: .scale))
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.86), value: restEndDate)
    }
    
    // MARK: - Current selections
    private var currentWorkoutDefinition: WorkoutDefinition? {
        guard vm.currentWorkoutIndex >= 0, vm.currentWorkoutIndex < vm.todaysWorkouts.count else { return nil }
        return vm.todaysWorkouts[vm.currentWorkoutIndex]
    }
    
    private var currentExerciseEntry: ExerciseEntry? {
        guard let workout = currentWorkoutDefinition else { return nil }
        return vm.exercise(for: workout.id)
    }
    
    private func startRestTimer() {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            let startDate = Date()
            restStartDate = startDate
            restEndDate = startDate.addingTimeInterval(defaultRestDuration)
        }
    }
    
    // MARK: - Sheets
    @ViewBuilder
    private func sheetContent(for sheet: ActiveSheet) -> some View {
        switch sheet {
        case .addExercise:
            AddExerciseSheet(name: $vm.newExerciseName) { vm.addExercise() }
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
    
    // MARK: - Session header
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
    
    // MARK: - Today plan + rows
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
                    
                    Button { activeSheet = .addExercise } label: {
                        Label("Add custom movement", systemImage: "plus")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(AtlasTheme.gradient.opacity(0.18), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(Array(vm.todaysWorkouts.enumerated()), id: \.offset) { index, workout in
                        if let exercise = vm.exercise(for: workout.id) {
                                ExerciseLoggingCard(
                                    workout: workout,
                                    exercise: exercise,
                                    targetSetCount: vm.targetSetCount(for: workout.id),
                                    isCurrent: index == vm.currentWorkoutIndex,
                                    isCompleted: vm.isCompleted(workout.id),
                                    isReadyForCompletion: vm.isReadyForCompletion(workout.id),
                                    isSetCompleted: { vm.isSetCompleted($0) },
                                    onSelect: {
                                        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                                            vm.selectWorkout(with: workout.id)
                                        }
                                },
                                onToggleComplete: {
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        vm.toggleCompletion(for: workout.id)
                                    }
                                },
                                onLogSet: { reps, weight, units in
                                    _ = vm.addSet(to: exercise.id, reps: reps, weight: weight, units: units)
                                    startRestTimer()
                                    vm.finalizeReadyWorkout(workout.id)
                                },
                                onToggleSetCompletion: { setID in
                                    withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                                        if !vm.isSetCompleted(setID) {
                                            startRestTimer()
                                        }
                                        vm.toggleSetCompletion(for: setID)
                                    }
                                    vm.finalizeReadyWorkout(workout.id)
                                },
                                onEditSet: { index, set in
                                    editExerciseID = exercise.id
                                    editSetIndex = index
                                    editReps = set.reps
                                    editWeight = set.weight
                                    editUnits = set.units
                                    vm.selectWorkout(with: workout.id)
                                    activeSheet = .editSet
                                },
                                onManageSets: {
                                    vm.selectWorkout(with: workout.id)
                                    activeSheet = .manageSets
                                }
                            )
                        }
                    }
                }
                .animation(.spring(response: 0.32, dampingFraction: 0.84), value: vm.todaysWorkouts)
                .animation(.spring(response: 0.32, dampingFraction: 0.84), value: vm.currentWorkoutIndex)

                Text("Log reps and weight within each card. Mark sets complete as you go to keep momentum.")
                    .font(.footnote)
                    .foregroundColor(.secondary)

                if showSetManagerCard,
                   let workout = currentWorkoutDefinition,
                   let exercise = currentExerciseEntry {
                    ManageSetsQuickCard(workout: workout, exercise: exercise) {
                        activeSheet = .manageSets
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 8)
                }
            }
        }
        .padding(24)
        .glassCard(cornerRadius: 26)
    }
}

private struct ExerciseLoggingCard: View {
    let workout: WorkoutDefinition
    let exercise: ExerciseEntry
    let targetSetCount: Int?
    let isCurrent: Bool
    let isCompleted: Bool
    let isReadyForCompletion: Bool
    var isSetCompleted: (UUID) -> Bool
    var onSelect: () -> Void
    var onToggleComplete: () -> Void
    var onLogSet: (_ reps: Int, _ weight: Double, _ units: Units) -> Void
    var onToggleSetCompletion: (_ setID: UUID) -> Void
    var onEditSet: (Int, SetEntry) -> Void
    var onManageSets: () -> Void

    private var plannedRows: Int {
        if shouldShowInputRow {
            return max(targetSetCount ?? 0, exercise.sets.count + 1)
        }
        return exercise.sets.count
    }

    private var shouldShowInputRow: Bool {
        !(isCompleted || isReadyForCompletion)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            Divider().opacity(0.08)

            VStack(spacing: 12) {
                ForEach(0..<plannedRows, id: \.self) { index in
                    if index < exercise.sets.count {
                        let set = exercise.sets[index]
                        LoggedSetSummaryRow(
                            index: index,
                            set: set,
                            isCompleted: isSetCompleted(set.id),
                            onToggleComplete: { onToggleSetCompletion(set.id) },
                            onEdit: { onEditSet(index, set) }
                        )
                    } else {
                        SetInputRow(
                            index: index,
                            previousSet: exercise.sets.last,
                            onLog: onLogSet
                        )
                    }
                }
            }

        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardFill)
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(cardStroke, lineWidth: isCurrent ? 1.2 : 1))
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
    }

    private var cardFill: some ShapeStyle {
        isCurrent
        ? AnyShapeStyle(AtlasTheme.gradient.opacity(0.18))
        : AnyShapeStyle(AtlasTheme.cardFill)
    }

    private var cardStroke: some ShapeStyle {
        isCurrent
        ? AnyShapeStyle(AtlasTheme.gradient)
        : AnyShapeStyle(AtlasTheme.border)
    }

    @ViewBuilder
    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(workout.name)
                        .font(.headline)
                        .foregroundColor(AtlasTheme.textPrimary)
                    Spacer()
                    if isCompleted {
                        Text("Done")
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
                    Spacer(minLength: 0)
                }

                Text(workout.summary)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(action: onToggleComplete) {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2.weight(.semibold))
                    .foregroundColor(isCompleted ? AtlasTheme.accentGreen : .secondary)
            }
            .buttonStyle(.plain)
        }
    }
}

private struct SetInputRow: View {
    let index: Int
    let previousSet: SetEntry?
    var onLog: (_ reps: Int, _ weight: Double, _ units: Units) -> Void

    @State private var reps: Int
    @State private var weight: Double
    @State private var units: Units
    @State private var isConfirming = false

    init(index: Int, previousSet: SetEntry?, onLog: @escaping (_ reps: Int, _ weight: Double, _ units: Units) -> Void) {
        self.index = index
        self.previousSet = previousSet
        self.onLog = onLog
        _reps = State(initialValue: previousSet?.reps ?? 8)
        _weight = State(initialValue: previousSet?.weight ?? 100)
        _units = State(initialValue: previousSet?.units ?? .lbs)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                Text("Set \(index + 1)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(AtlasTheme.textPrimary)
                Spacer()
                logButton
            }

            HStack(spacing: 12) {
                CompactIntAdjuster(title: "Reps", value: $reps, range: 1...100)
                CompactDoubleAdjuster(title: "Weight", value: $weight, step: 5)
                    .frame(maxWidth: 150)
            }
        }
        .padding(12)
        .background(AtlasTheme.cardFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AtlasTheme.border, lineWidth: 1)
        )
    }

    private var logButton: some View {
        Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                isConfirming = true
            }
            onLog(reps, weight, units)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                withAnimation(.easeOut(duration: 0.25)) {
                    isConfirming = false
                }
            }
        } label: {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(.white)
                .padding(8)
                .background(
                    Circle()
                        .fill(AtlasTheme.gradient)
                        .shadow(color: AtlasTheme.accentGreen.opacity(0.24), radius: 6, x: 0, y: 3)
                )
                .scaleEffect(isConfirming ? 0.9 : 1.0)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Log set \(index + 1)")
    }
}

private struct LoggedSetSummaryRow: View {
    let index: Int
    let set: SetEntry
    let isCompleted: Bool
    var onToggleComplete: () -> Void
    var onEdit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                Text("Set \(index + 1)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(AtlasTheme.textPrimary)
                Spacer()
                Button(action: onToggleComplete) {
                    Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(isCompleted ? AtlasTheme.accentGreen : .secondary)
                }
                .buttonStyle(.plain)
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 10) {
                Text("\(set.reps) reps")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(AtlasTheme.gradient.opacity(0.22), in: Capsule())
                Text(weightText)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer(minLength: 0)
            }
        }
        .padding(12)
        .background(AtlasTheme.cardFill.opacity(0.9), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isCompleted ? AnyShapeStyle(AtlasTheme.accentGreen.opacity(0.6)) : AnyShapeStyle(AtlasTheme.border), lineWidth: 1)
        )
    }

    private var weightText: String {
        let weightValue: String
        if set.weight.truncatingRemainder(dividingBy: 1) == 0 {
            weightValue = String(format: "%.0f", set.weight)
        } else {
            weightValue = String(format: "%.1f", set.weight)
        }
        return "\(weightValue) \(set.units.rawValue)"
    }
}

private struct AddExerciseSheet: View {
    @Binding var name: String
    var onAdd: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Exercise Name") { TextField("e.g., Bench Press", text: $name) }
            }
            .navigationTitle("Add Exercise")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") { onAdd(); dismiss() }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
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
                        Text("No sets logged yet — add one from the exercise card below.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    } else {
                        VStack(spacing: 12) {
                            ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { index, set in
                                Button { onSelectSet(index, set) } label: {
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
                                .transition(.setRow)
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

// MARK: - Controls (adjusters)

private struct LoggedSetList: View { // unchanged, not used in the bottom logger anymore
    @ObservedObject var vm: StartWorkoutViewModel
    let exercise: ExerciseEntry
    var onSetCompleted: () -> Void
    var onEdit: (Int, SetEntry) -> Void
    var onManage: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Text("Logged Sets")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Button(action: onManage) {
                    Label("Manage", systemImage: "slider.horizontal.3")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(AtlasTheme.accentGreen)
            }
            
            VStack(spacing: 10) {
                ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { index, set in
                    LoggedSetRow(
                        index: index,
                        set: set,
                        isCompleted: vm.isSetCompleted(set.id),
                        onMarkComplete: {
                            if !vm.isSetCompleted(set.id) {
                                onSetCompleted()
                            }
                        },
                        onToggleComplete: {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                                vm.toggleSetCompletion(for: set.id)
                            }
                        },
                        onEdit: {
                            onEdit(index, set)
                        },
                        onDelete: {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
                                vm.removeSet(from: exercise.id, setID: set.id)
                            }
                        }
                    )
                    .transition(.setRow)
                }
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.82), value: exercise.sets)
        .animation(.spring(response: 0.32, dampingFraction: 0.82), value: vm.completedSetIDs)
    }
}

private struct LoggedSetRow: View {
    let index: Int
    let set: SetEntry
    let isCompleted: Bool
    var onMarkComplete: () -> Void
    var onToggleComplete: () -> Void
    var onEdit: () -> Void
    var onDelete: () -> Void
    
    @State private var dragOffset: CGFloat = 0
    @State private var didTriggerHaptic = false
    
    private let completionThreshold: CGFloat = 96
    
    var body: some View {
        let progress = min(1, max(0, dragOffset / completionThreshold))
        let backgroundOpacity = isCompleted ? 0.38 : 0.16 + (0.25 * progress)
        let strokeOpacity = isCompleted ? 0.9 : 0.25 + (0.45 * progress)
        
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                Text("Set \(index + 1)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(AtlasTheme.textPrimary)
                Spacer()
                if isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AtlasTheme.accentGreen)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            
            HStack(spacing: 8) {
                Text("\(set.reps) reps")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(AtlasTheme.gradient.opacity(0.22), in: Capsule())
                
                Text("\(formattedWeight) \(set.units.rawValue)")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(AtlasTheme.gradient.opacity(0.16), in: Capsule())
                
                Spacer(minLength: 0)
            }
            .foregroundColor(AtlasTheme.textPrimary)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(AtlasTheme.gradient.opacity(backgroundOpacity))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(AtlasTheme.gradient.opacity(strokeOpacity), lineWidth: 1.4)
        )
        .opacity(isCompleted ? 0.68 : 1)
        .offset(x: dragOffset)
        .gesture(dragGesture)
        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: dragOffset)
        .contextMenu {
            Button("Edit Set", action: onEdit)
            if isCompleted {
                Button("Mark Incomplete") { onToggleComplete() }
            } else {
                Button("Mark Complete") {
                    onMarkComplete()
                    onToggleComplete()
                }
            }
            Divider()
            Button(role: .destructive, action: onDelete) {
                Label("Delete Set", systemImage: "trash")
            }
        }
        .onTapGesture {
            if isCompleted {
                onToggleComplete()
            } else {
                onMarkComplete()
                onToggleComplete()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Set \(index + 1). \(set.reps) reps at \(formattedWeight) \(set.units.rawValue)")
    }
    
    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                let translation = max(0, value.translation.width)
                dragOffset = translation
                let ratio = translation / completionThreshold
                if ratio >= 1, !didTriggerHaptic {
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    didTriggerHaptic = true
                } else if ratio < 0.6 {
                    didTriggerHaptic = false
                }
            }
            .onEnded { value in
                let translation = max(0, value.translation.width)
                let shouldComplete = translation > completionThreshold
                withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                    dragOffset = 0
                }
                if shouldComplete {
                    if !isCompleted {
                        onMarkComplete()
                        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                        onToggleComplete()
                    }
                }
            }
    }
    
    private var formattedWeight: String {
        if set.weight.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", set.weight)
        }
        return String(format: "%.1f", set.weight)
    }
}

private struct CompactIntAdjuster: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    var step: Int = 1
    
    @State private var isEditingText = false
    @State private var textBuffer = ""
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundColor(.secondary)
            
            HStack(spacing: 0) {
                StepButton(systemName: "minus") { value = max(range.lowerBound, value - step) }
                
                ZStack {
                    if isEditingText {
                        TextField("", text: $textBuffer)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.center)
                            .font(.headline.bold())
                            .monospacedDigit()
                            .frame(minWidth: 42)
                            .foregroundColor(AtlasTheme.textPrimary)
                            .focused($isFocused)
                            .onAppear {
                                textBuffer = String(value)
                                isFocused = true
                            }
                            .onSubmit(commit)
                            .toolbar {
                                ToolbarItemGroup(placement: .keyboard) {
                                    Spacer()
                                    Button("Done") {
                                        commit()
                                        isFocused = false
                                    }
                                }
                            }
                    } else {
                        Text("\(value)")
                            .font(.headline.bold())
                            .monospacedDigit()
                            .frame(minWidth: 42)
                            .multilineTextAlignment(.center)
                            .foregroundColor(AtlasTheme.textPrimary)
                            .onTapGesture { isEditingText = true }
                    }
                }
                
                StepButton(systemName: "plus") { value = min(range.upperBound, value + step) }
            }
            .background(AtlasTheme.cardFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(AtlasTheme.border, lineWidth: 1)
            )
        }
    }
    
    private func commit() {
        if let intVal = Int(textBuffer) {
            value = min(max(range.lowerBound, intVal), range.upperBound)
        }
        isEditingText = false
    }
}

private struct CompactDoubleAdjuster: View {
    let title: String
    @Binding var value: Double
    var step: Double = 2.5
    
    @State private var isEditingText = false
    @State private var textBuffer = ""
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundColor(.secondary)
            
            HStack(spacing: 0) {
                StepButton(systemName: "minus") { value = max(0, value - step) }
                
                ZStack {
                    if isEditingText {
                        TextField("", text: $textBuffer)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.center)
                            .font(.headline.bold())
                            .monospacedDigit()
                            .frame(minWidth: 50)
                            .foregroundColor(AtlasTheme.textPrimary)
                            .focused($isFocused)
                            .onAppear {
                                // Preserve user-entered precision while editing
                                if value.truncatingRemainder(dividingBy: 1) == 0 {
                                    textBuffer = String(format: "%.0f", value)
                                } else {
                                    textBuffer = String(value)
                                }
                                isFocused = true
                            }
                            .onSubmit(commit)
                            .toolbar {
                                ToolbarItemGroup(placement: .keyboard) {
                                    Spacer()
                                    Button("Done") {
                                        commit()
                                        isFocused = false
                                    }
                                }
                            }
                    } else {
                        Text(displayValue)
                            .font(.headline.bold())
                            .monospacedDigit()
                            .frame(minWidth: 50)
                            .multilineTextAlignment(.center)
                            .foregroundColor(AtlasTheme.textPrimary)
                            .onTapGesture { isEditingText = true }
                    }
                }
                
                StepButton(systemName: "plus") { value += step }
            }
            .background(AtlasTheme.cardFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(AtlasTheme.border, lineWidth: 1)
            )
        }
    }
    
    private var displayValue: String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", value)
        } else {
            return String(format: "%.1f", value)
        }
    }
    
    private func commit() {
        let sanitized = textBuffer.replacingOccurrences(of: ",", with: ".")
        if let doubleVal = Double(sanitized) {
            value = max(0, doubleVal)
        }
        isEditingText = false
    }
}

private struct StepButton: View {
    let systemName: String
    let action: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button {
            withAnimation(.easeOut(duration: 0.15)) { isPressed = true }
            action()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.easeOut(duration: 0.2)) { isPressed = false }
            }
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
                .scaleEffect(isPressed ? 0.88 : 1.0)
        }
        .buttonStyle(.plain)
    }
}

private struct ManageSetsQuickCard: View {
    let workout: WorkoutDefinition
    let exercise: ExerciseEntry
    let onOpen: () -> Void
    
    private var setSummary: String {
        "\(exercise.sets.count) set\(exercise.sets.count == 1 ? "" : "s") logged"
    }
    
    private var bestSetDescription: String? {
        guard let best = exercise.sets.max(by: { $0.weight < $1.weight }) else { return nil }
        let repsText = "\(best.reps) reps"
        let weightText: String
        if best.weight.truncatingRemainder(dividingBy: 1) == 0 {
            weightText = String(format: "%.0f %@", best.weight, best.units.rawValue)
        } else {
            weightText = String(format: "%.1f %@", best.weight, best.units.rawValue)
        }
        return "Top set: \(repsText) @ \(weightText)"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(workout.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(AtlasTheme.textPrimary)
                    Text(exercise.name)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer(minLength: 0)
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(setSummary)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(AtlasTheme.accentGreen)
                    if let best = bestSetDescription {
                        Text(best)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            if !exercise.sets.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { index, set in
                            SetSnapshotCapsule(index: index, set: set)
                                .transition(.setRow)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .animation(.easeInOut(duration: 0.25), value: exercise.sets)
            }
            
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 24)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(setSummary) for \(exercise.name). Tap to view or edit sets.")
    }
}

private struct SetSnapshotCapsule: View {
    let index: Int
    let set: SetEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Set \(index + 1)")
                .font(.caption2.weight(.semibold))
                .foregroundColor(.secondary)
            Text("\(set.reps) × \(weightText) \(set.units.rawValue)")
                .font(.caption)
                .foregroundColor(AtlasTheme.textPrimary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AtlasTheme.gradient.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AtlasTheme.gradient.opacity(0.6), lineWidth: 1)
        )
    }
    
    private var weightText: String {
        if set.weight.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", set.weight)
        } else {
            return String(format: "%.1f", set.weight)
        }
    }
}

private struct RestTimerOverlay: View {
    let startDate: Date
    let endDate: Date
    let duration: TimeInterval
    var onCancel: (_ elapsed: TimeInterval) -> Void
    var onReachedZero: () -> Void

    @State private var completionDispatched = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.016, paused: false)) { timeline in
            let remaining = endDate.timeIntervalSince(timeline.date)
            let isOvertime = remaining <= 0
            let displayedTime = abs(remaining)
            let secondsRemaining = Int(ceil(displayedTime))
            let minutes = secondsRemaining / 60
            let seconds = secondsRemaining % 60
            let progress = max(0, min(1, remaining / duration))

            ZStack {
                Color.black.opacity(0.45).ignoresSafeArea()
                BreathingBackground()
                
                VStack(spacing: 28) {
                    Text("Rest")
                        .font(.title2.bold())
                        .gradientForeground()
                    
                    ZStack {
                        Circle()
                            .fill(AtlasTheme.gradient.opacity(0.12))
                        Circle()
                            .stroke(.white.opacity(0.08), lineWidth: 1.6)
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(style: StrokeStyle(lineWidth: 12, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .foregroundStyle(timerStroke(forOvertime: isOvertime))
                            .shadow(
                                color: (isOvertime ? Color.red : AtlasTheme.accentGreen).opacity(0.25),
                                radius: 8,
                                x: 0,
                                y: 4
                            )
                            .animation(.linear(duration: 0.2), value: progress)
                      }
                      .frame(width: 200, height: 200)

                    Text("\(isOvertime ? "-" : "")\(minutes):\(String(format: "%02d", seconds))")
                        .font(.system(size: 44, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(isOvertime ? .red : AtlasTheme.textPrimary)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.45, dampingFraction: 0.82), value: secondsRemaining)

                    Text(isOvertime ? "Rest window passed — let's move" : (progress < 0.7 ? "Breathe deep — stay loose" : "Almost time to move"))
                        .font(.subheadline)
                        .foregroundStyle(isOvertime ? .red.opacity(0.8) : .secondary)

                    Button("Skip Rest") {
                        onCancel(max(0, Date().timeIntervalSince(startDate)))
                    }
                        .buttonStyle(AtlasButtonStyle())
                }
                .padding(32)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
                .shadow(color: Color.black.opacity(0.22), radius: 24, x: 0, y: 18)
                .padding(.horizontal, 24)
            }
            .transition(.opacity)
            .onChange(of: isOvertime) { _, newValue in
                if newValue, !completionDispatched {
                    completionDispatched = true
                    onReachedZero()
                }
            }
        }
        .onAppear { completionDispatched = false }
        .onChange(of: endDate) { _, _ in completionDispatched = false }
    }

    private func timerStroke(forOvertime isOvertime: Bool) -> some ShapeStyle {
        if isOvertime {
            return LinearGradient(colors: [.red, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        return AtlasTheme.gradient
    }
}

private struct BreathingBackground: View {
    @State private var breathe = false
    
    var body: some View {
        ZStack {
            Circle()
                .fill(AtlasTheme.gradient)
                .frame(width: 420, height: 420)
                .scaleEffect(breathe ? 1.14 : 0.9)
                .blur(radius: breathe ? 44 : 16)
                .opacity(0.42)

            Circle()
                .fill(AtlasTheme.gradientAlt)
                .frame(width: 260, height: 260)
                .scaleEffect(breathe ? 0.88 : 1.12)
                .blur(radius: breathe ? 34 : 12)
                .opacity(0.36)
        }
        .animation(.easeInOut(duration: 3.6).repeatForever(autoreverses: true), value: breathe)
        .onAppear { breathe = true }
        .allowsHitTesting(false)
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
            .toolbar { ToolbarItem(placement: .primaryAction) { Button("Save", action: onSave) } }
        }
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
        
        let fillStyle: AnyShapeStyle = isCurrent
        ? AnyShapeStyle(AtlasTheme.gradient.opacity(0.18))
        : AnyShapeStyle(AtlasTheme.cardFill)
        let strokeStyle: AnyShapeStyle = isCurrent
        ? AnyShapeStyle(AtlasTheme.gradient)
        : AnyShapeStyle(AtlasTheme.border)
        let strokeWidth: CGFloat = isCurrent ? 1.2 : 1.0
        let statusText: String? = showDone ? "Done" : (showInProgress ? "In progress" : nil)
        
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: showDone ? "checkmark.circle.fill" : "circle")
                .font(.title2.weight(.semibold))
                .foregroundColor(showDone ? AtlasTheme.accentGreen : .secondary)
                .frame(width: 34, height: 34)
                .onTapGesture(perform: onToggleComplete)
            
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text(workout.name).font(.headline).foregroundColor(AtlasTheme.textPrimary)
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
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(fillStyle))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(strokeStyle, lineWidth: strokeWidth))
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .opacity(rowOpacity)
        .accessibilityAddTraits(.isButton)
    }
}

private extension AnyTransition {
    static var setRow: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .top).combined(with: .opacity),
            removal: .scale(scale: 0.85, anchor: .center).combined(with: .opacity)
        )
    }
}

#Preview("Dark")  { AtlasTabRoot().preferredColorScheme(.dark) }
