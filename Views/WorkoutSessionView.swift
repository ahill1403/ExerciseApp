//
//  WorkoutSessionView.swift
//  REPS
//
//  Created by Aaron Hill on 10/28/25.
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

    private let setCardAnimation = Animation.spring(response: 0.32, dampingFraction: 0.82)

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
                activeSheet: $activeSheet
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
                            ForEach(Array(exercise.sets.enumerated()), id: \.offset) { index, set in
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
                        ForEach(Array(exercise.sets.enumerated()), id: \.offset) { index, set in
                            SetSnapshotCapsule(index: index, set: set)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .padding(.vertical, 2)
                }
                .animation(.easeInOut(duration: 0.25), value: exercise.sets)
            }

            Button(action: onOpen) {
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

#Preview("Dark")  { AtlasTabRoot().preferredColorScheme(.dark) }
