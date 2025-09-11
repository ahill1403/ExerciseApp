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
        .toolbar {
            if vm.isLogging {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { vm.reset(); dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Finish") { showFinishAlert = true }
                }
            }
        }
        .alert("Finish Workout?", isPresented: $showFinishAlert) {
            Button("Save", role: .none) {
                vm.finish()
                dismiss()
            }
            Button("Keep Logging", role: .cancel) { }
        } message: {
            Text("Your session will be saved to Progress.")
        }
        .sheet(isPresented: $vm.showAddExercise) {
            AddExerciseSheet(name: $vm.newExerciseName) { vm.addExercise() }
        }
    }

    // MARK: - Template Picker
    private var templatePicker: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Pick a template")
                    .font(.title2.bold())
                    .gradientForeground()
                    .frame(maxWidth: .infinity, alignment: .leading)

                LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 12) {
                    ForEach(vm.templates, id: \.self) { t in
                        Button {
                            vm.start(template: t)
                        } label: {
                            HStack {
                                Image(systemName: "bolt.fill")
                                Text(t)
                                Spacer()
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity)
                            .background(AtlasTheme.gradient.opacity(0.20), in: RoundedRectangle(cornerRadius: 16))
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
                    ForEach(exercise.sets) { set in
                        HStack {
                            Text("Set \(exercise.sets.firstIndex(of: set)! + 1)")
                            Spacer()
                            Text("\(set.reps) reps × \(set.weight, specifier: "%.0f") \(set.units.rawValue)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    AddSetRow {
                        // show inline add UI
                        AddSetInline { reps, weight, units in
                            vm.addSet(to: exercise.id, reps: reps, weight: weight, units: units)
                        }
                    }
                    Button(role: .destructive) {
                        vm.removeExercise(exercise.id)
                    } label: { Text("Remove Exercise") }
                }
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(.clear)
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
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") { onAdd(); dismiss() }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

private struct AddSetRow<Content: View>: View {
    var content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            content()
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
            } label: { Image(systemName: "plus.circle.fill").font(.title3) }
        }
    }
}
