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
    
    private let setCardAnimation = Animation.spring(response: 0.32, dampingFraction: 0.82)
    private let defaultRestDuration: TimeInterval = 90
    
    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    sessionHeader
                    todaysPlanSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 160)
            }
            
            LoggingPanel(
                vm: vm,
                currentWorkoutDefinition: currentWorkoutDefinition,
                currentExerciseEntry: currentExerciseEntry,
                editExerciseID: $editExerciseID,
                editSetIndex: $editSetIndex,
                editReps: $editReps,
                editWeight: $editWeight,
                editUnits: $editUnits,
                activeSheet: $activeSheet,
                onSetCompleted: startRestTimer
            )
            .transition(.move(edge: .bottom).combined(with: .opacity))
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
                    Button("Autofill last") { vm.autofillFromLast() }
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
        .onChange(of: currentExerciseEntry?.id) { _ in
            withAnimation(setCardAnimation) {
                showSetManagerCard = (currentExerciseEntry?.sets.isEmpty == false)
            }
        }
        .onChange(of: currentExerciseEntry?.sets.count ?? 0) { newValue in
            withAnimation(setCardAnimation) {
                showSetManagerCard = newValue > 0
            }
        }
        .onChange(of: vm.isLogging) { isLogging in
            if !isLogging {
                restEndDate = nil
            }
        }
        .overlay {
            if let endDate = restEndDate {
                RestTimerOverlay(
                    endDate: endDate,
                    duration: defaultRestDuration,
                    onCancel: {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                            restEndDate = nil
                        }
                    },
                    onComplete: {
                        withAnimation(.spring(response: 0.55, dampingFraction: 0.8)) {
                            restEndDate = nil
                        }
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
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
            restEndDate = Date().addingTimeInterval(defaultRestDuration)
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
                .animation(.spring(response: 0.32, dampingFraction: 0.84), value: vm.todaysWorkouts)
                .animation(.spring(response: 0.32, dampingFraction: 0.84), value: vm.currentWorkoutIndex)
                
                Text("Tap a card to focus logging on that workout. Check it off once you've completed the sets.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                
                if showSetManagerCard,
                   let workout = currentWorkoutDefinition,
                   let exercise = currentExerciseEntry {
                    ManageSetsQuickCard(
                        vm: vm,
                        workout: workout,
                        exercise: exercise,
                        onSetCompleted: startRestTimer,
                        onEdit: { index, set in
                            editExerciseID = exercise.id
                            editSetIndex = index
                            editReps = set.reps
                            editWeight = set.weight
                            editUnits = set.units
                            activeSheet = .editSet
                        },
                        onManage: { activeSheet = .manageSets }
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 8)
                }
            }
        }
        .padding(24)
        .glassCard(cornerRadius: 26)
    }
}

// MARK: - Logging panel + controls

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
    var onSetCompleted: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
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
                }
                
                Divider().opacity(0.08)
                
                AddSetInline { reps, weight, units in
                    vm.addSet(to: exercise.id, reps: reps, weight: weight, units: units)
                }
                .padding(.top, 4)
                
                if !exercise.sets.isEmpty {
                    Divider()
                        .opacity(0.08)
                        .padding(.vertical, 12)

                    LoggedSetSummaryFooter(
                        exercise: exercise,
                        onManage: { activeSheet = .manageSets }
                    )
                }
                
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
            
            if !vm.todaysWorkouts.isEmpty { Divider().opacity(0.08) }
        }
        .padding(.top, 4)
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            UnevenRoundedRectangle(
                cornerRadii: .init(topLeading: 28, bottomLeading: 0, bottomTrailing: 0, topTrailing: 28)
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
                        Text("No sets logged yet — add one from the logger below.")
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

private struct AddSetInline: View {
    @State private var reps: Int = 8
    @State private var weight: Double = 100
    @State private var units: Units = .lbs
    @State private var isConfirming = false
    var onAdd: (_ reps: Int, _ weight: Double, _ units: Units) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .bottom, spacing: 12) {
                    CompactIntAdjuster(title: "Reps", value: $reps, range: 1...100)
                    CompactDoubleAdjuster(title: "Weight", value: $weight, step: 5)
                        .frame(width: 140)
                    logButton
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        CompactIntAdjuster(title: "Reps", value: $reps, range: 1...100)
                        CompactDoubleAdjuster(title: "Weight", value: $weight, step: 5)
                    }
                    HStack(spacing: 12) { logButton }
                }
            }
        }
    }
    
    private var logButton: some View {
        Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                isConfirming = true
            }
            onAdd(reps, weight, units)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                withAnimation(.easeOut(duration: 0.25)) {
                    isConfirming = false
                }
            }
        } label: {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white)
                .padding(10)
                .background(
                    Circle()
                        .fill(AtlasTheme.gradient)
                        .shadow(color: AtlasTheme.accentGreen.opacity(0.24), radius: 8, x: 0, y: 4)
                )
                .scaleEffect(isConfirming ? 0.9 : 1.0)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Log set")
    }
}

private struct LoggedSetList: View {
    @ObservedObject var vm: StartWorkoutViewModel
    let exercise: ExerciseEntry
    var showHeader: Bool = true
    var showManageButton: Bool = true
    var onSetCompleted: () -> Void
    var onEdit: (Int, SetEntry) -> Void
    var onManage: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if showHeader || showManageButton {
                HStack(spacing: 12) {
                    if showHeader {
                        Text("Logged Sets")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if showManageButton {
                        Button(action: onManage) {
                            Label("Manage", systemImage: "slider.horizontal.3")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(AtlasTheme.accentGreen)
                    }
                }
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

private struct LoggedSetSummaryFooter: View {
    let exercise: ExerciseEntry
    var onManage: () -> Void

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
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(setSummary)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(AtlasTheme.accentGreen)

                if let best = bestSetDescription {
                    Text(best)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Button(action: onManage) {
                Label("Review logged sets", systemImage: "slider.horizontal.3")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(AtlasButtonStyle())
        }
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
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.35, dampingFraction: 0.86), value: set.reps)
                
                Text("\(formattedWeight) \(set.units.rawValue)")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(AtlasTheme.gradient.opacity(0.16), in: Capsule())
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.35, dampingFraction: 0.86), value: formattedWeight)
                
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundColor(.secondary)
            
            HStack(spacing: 0) {
                StepButton(systemName: "minus") { value = max(range.lowerBound, value - step) }
                Text("\(value)")
                    .font(.headline.bold()) // compact size (was title3)
                    .frame(minWidth: 42)    // compact width (was 54)
                    .multilineTextAlignment(.center)
                    .foregroundColor(AtlasTheme.textPrimary)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.32, dampingFraction: 0.85), value: value)
                StepButton(systemName: "plus") { value = min(range.upperBound, value + step) }
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
                StepButton(systemName: "minus") { value = max(0, value - step) }
                Text(value.formatted(.number.precision(.fractionLength(0))))
                    .font(.headline.bold()) // compact size (was title3)
                    .frame(minWidth: 50)    // compact width (was 64)
                    .multilineTextAlignment(.center)
                    .foregroundColor(AtlasTheme.textPrimary)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.32, dampingFraction: 0.85), value: value)
                StepButton(systemName: "plus") { value += step }
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
    @ObservedObject var vm: StartWorkoutViewModel
    let workout: WorkoutDefinition
    let exercise: ExerciseEntry
    var onSetCompleted: () -> Void
    var onEdit: (Int, SetEntry) -> Void
    var onManage: () -> Void

    @State private var isExpanded = false
    
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

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 14, weight: .semibold))
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isExpanded)

                        Text("Logged Sets")
                            .font(.caption.weight(.semibold))

                        Spacer()

                        Text("\(exercise.sets.count)")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(AtlasTheme.gradient.opacity(0.12), in: Capsule())
                    }
                    .foregroundColor(AtlasTheme.textPrimary)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)

                if isExpanded {
                    LoggedSetList(
                        vm: vm,
                        exercise: exercise,
                        showHeader: false,
                        showManageButton: false,
                        onSetCompleted: onSetCompleted,
                        onEdit: onEdit,
                        onManage: onManage
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 4)
                }
            }

            Button(action: onManage) {
                Label("View / Edit Sets", systemImage: "slider.horizontal.3")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(AtlasButtonStyle())
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 24)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(setSummary) for \(exercise.name). Tap to view or edit sets.")
        .onChange(of: exercise.sets.count) { count in
            if count == 0 {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                    isExpanded = false
                }
            }
        }
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
    let endDate: Date
    let duration: TimeInterval
    var onCancel: () -> Void
    var onComplete: () -> Void
    
    @State private var completionDispatched = false
    
    var body: some View {
        TimelineView(.animation(minimumInterval: 0.016, paused: false)) { timeline in
            let remaining = max(0, endDate.timeIntervalSince(timeline.date))
            let ratio = duration > 0 ? remaining / duration : 0
            let progress = 1 - ratio
            let secondsRemaining = max(0, Int(ceil(remaining)))
            let minutes = secondsRemaining / 60
            let seconds = secondsRemaining % 60
            
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
                            .trim(from: 0, to: CGFloat(max(0.001, ratio)))
                            .stroke(style: StrokeStyle(lineWidth: 12, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .foregroundStyle(AtlasTheme.gradient)
                            .hueRotation(.degrees(progress * 90))
                            .shadow(color: AtlasTheme.accentGreen.opacity(0.25), radius: 8, x: 0, y: 4)
                            .animation(.easeInOut(duration: 0.25), value: ratio)
                    }
                    .frame(width: 200, height: 200)
                    
                    Text(String(format: "%d:%02d", minutes, seconds))
                        .font(.system(size: 44, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(AtlasTheme.textPrimary)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.45, dampingFraction: 0.82), value: secondsRemaining)
                    
                    Text(progress < 0.7 ? "Breathe deep — stay loose" : "Almost time to move")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Button("Skip Rest", action: onCancel)
                        .buttonStyle(AtlasButtonStyle())
                }
                .padding(32)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
                .shadow(color: Color.black.opacity(0.22), radius: 24, x: 0, y: 18)
                .padding(.horizontal, 24)
            }
            .transition(.opacity)
            .onChange(of: secondsRemaining) { newValue in
                if newValue == 0, !completionDispatched {
                    completionDispatched = true
                    onComplete()
                }
            }
        }
        .onAppear { completionDispatched = false }
        .onChange(of: endDate) { _ in completionDispatched = false }
    }
}

private struct BreathingBackground: View {
    @State private var breathe = false
    
    var body: some View {
        ZStack {
            Circle()
                .fill(AtlasTheme.gradient)
                .frame(width: 420, height: 420)
                .scaleEffect(breathe ? 1.08 : 0.94)
                .blur(radius: breathe ? 36 : 18)
                .opacity(0.38)
            
            Circle()
                .fill(AtlasTheme.gradientAlt)
                .frame(width: 260, height: 260)
                .scaleEffect(breathe ? 0.92 : 1.05)
                .blur(radius: breathe ? 28 : 14)
                .opacity(0.32)
        }
        .animation(.easeInOut(duration: 4.5).repeatForever(autoreverses: true), value: breathe)
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
