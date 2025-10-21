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

    private let gridCols: [GridItem] = [GridItem(.flexible()), GridItem(.flexible())]

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
        .onAppear { vm.refreshPlanSuggestion() }
        .toolbar {
            if vm.isLogging {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { vm.reset(); dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Button("Autofill last") { autofillFromLast() }
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
            VStack(spacing: 16) {
                suggestionCard

                Text("Pick a template")
                    .font(.title2.bold())
                    .gradientForeground()
                    .frame(maxWidth: .infinity, alignment: .leading)

                LazyVGrid(columns: gridCols, spacing: 12) {
                    ForEach(vm.templates, id: \.self) { t in
                        Button { vm.start(template: t) } label: {
                            HStack {
                                Image(systemName: "bolt.fill")
                                Text(t)
                                Spacer()
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity)
                            .background(AtlasTheme.gradient.opacity(0.16),
                                        in: RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(.plain)
                    }
                }

                Button("Start Empty Session") { vm.start(template: "Custom") }
                    .buttonStyle(AtlasButtonStyle())
                    .padding(.top, 8)
            }
            .padding(20)
        }
        .safeAreaPadding(.bottom, 160)
    }

    @ViewBuilder
    private var suggestionCard: some View {
        if let suggestion = vm.planSuggestion {
            let focusNames = suggestion.areas.map { $0.displayName }
            let focusSummary = focusNames.joined(separator: " • ")
            let dayName = weekdayName(for: suggestion.day)

            VStack(alignment: .leading, spacing: 12) {
                Text(suggestion.isToday ? "Today's plan" : suggestion.offset == 1 ? "Tomorrow's plan" : "Next workout")
                    .font(.headline)
                    .gradientForeground()

                if suggestion.isToday {
                    Text(focusSummary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("\(dayName) • \(focusSummary)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    ForEach(focusNames, id: \.self) { name in
                        Text(name)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(AtlasTheme.gradient.opacity(0.18), in: Capsule())
                    }
                }

                VStack(spacing: 8) {
                    ForEach(suggestion.templates, id: \.self) { template in
                        Button {
                            vm.start(template: template)
                        } label: {
                            HStack {
                                Image(systemName: "play.fill")
                                Text(template)
                                Spacer()
                                if template == suggestion.templates.first {
                                    Text("Recommended")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity)
                            .background(AtlasTheme.gradient.opacity(0.16), in: RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                    }
                }

                Text("Based on your weekly plan. You can always adjust days in Planner.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .glassCard(cornerRadius: 18)
        }
    }

    private func weekdayName(for day: Int) -> String {
        let symbols = Calendar.current.weekdaySymbols
        let idx = (day - 1 + symbols.count) % symbols.count
        return symbols[idx]
    }

    // MARK: - Session Logger
    private var sessionLogger: some View {
        List {
            Section {
                HStack {
                    Text(vm.selectedTemplate ?? "Workout")
                        .font(.title3.bold())
                    Spacer()
                    if let start = vm.startTime {
                        Text(start, style: .timer)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
                .listRowBackground(Color.clear)

                Button {
                    vm.showAddExercise = true
                } label: {
                    Label("Add Exercise", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.clear)
            }

            ForEach(vm.exercises) { exercise in
                Section(exercise.name) {
                    let enumeratedSets = Array(exercise.sets.enumerated())

                    ForEach(enumeratedSets, id: \.offset) { index, set in
                        HStack {
                            Text("Set \(index + 1)")
                            Spacer()
                            Text("\(set.reps) reps × \(set.weight, specifier: "%.0f") \(set.units.rawValue)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
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

                    AddSetRow {
                        AddSetInline { reps, weight, units in
                            vm.addSet(to: exercise.id, reps: reps, weight: weight, units: units)
                        }
                    }

                    Button(role: .destructive) {
                        vm.removeExercise(exercise.id)
                    } label: {
                        Text("Remove Exercise")
                    }
                }
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(.clear)
    }

    // MARK: - Autofill from last session (view-local, no VM change required)
    private func autofillFromLast() {
        guard let template = vm.selectedTemplate else { return }
        let history = WorkoutStore.shared.load()
        guard let last = history.last(where: { $0.template == template }) else { return }
        vm.exercises = last.exercises.map { ex in
            var copy = ExerciseEntry(name: ex.name)
            copy.sets = ex.sets.map { SetEntry(reps: $0.reps, weight: $0.weight, units: $0.units) }
            return copy
        }
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

private struct AddSetRow<Content: View>: View {
    var content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: 8) { content() }
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
