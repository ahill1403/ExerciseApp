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

#Preview("Light") { AtlasTabRoot().preferredColorScheme(.light) }
#Preview("Dark")  { AtlasTabRoot().preferredColorScheme(.dark) }
