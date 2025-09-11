//
//  StartWorkoutViewModel.swift
//  AtlasFit
//
//  Created by Aaron Hill on 9/11/25.
//

import Foundation

@MainActor
final class StartWorkoutViewModel: ObservableObject {
    @Published var selectedTemplate: String?
    @Published var isLogging = false
    @Published var exercises: [ExerciseEntry] = []
    @Published var startTime: Date?

    // Sheets
    @Published var showAddExercise = false
    @Published var newExerciseName = ""
    @Published var editingExercise: ExerciseEntry?

    let templates = ["Full Body", "Upper Body", "Lower Body", "Push", "Pull", "Legs", "Core", "Custom"]

    func start(template: String) {
        selectedTemplate = template
        isLogging = true
        exercises = []
        startTime = Date()
    }

    func addExercise() {
        let name = newExerciseName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        exercises.append(ExerciseEntry(name: name))
        newExerciseName = ""
        showAddExercise = false
    }

    func addSet(to exerciseID: UUID, reps: Int, weight: Double, units: Units) {
        guard let idx = exercises.firstIndex(where: { $0.id == exerciseID }) else { return }
        exercises[idx].sets.append(SetEntry(reps: reps, weight: weight, units: units))
    }

    func removeExercise(_ exerciseID: UUID) {
        exercises.removeAll { $0.id == exerciseID }
    }

    func finish() {
        guard let template = selectedTemplate else { return }
        let duration = startTime.map { Date().timeIntervalSince($0) }
        let session = WorkoutSession(date: Date(), template: template, exercises: exercises, duration: duration)
        WorkoutStore.shared.add(session)
        reset()
    }

    func reset() {
        selectedTemplate = nil
        isLogging = false
        exercises = []
        startTime = nil
    }
}
