import Foundation
#if canImport(HealthKit)
import HealthKit
#endif

@MainActor
final class StartWorkoutViewModel: ObservableObject {
    @Published var selectedTemplate: String?
    @Published var isLogging = false
    @Published var exercises: [ExerciseEntry] = []
    @Published var startTime: Date?

    // Sheets
    @Published var showAddExercise = false
    @Published var newExerciseName = ""

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

    func autofillFromLast() {
        guard let template = selectedTemplate else { return }
        let last = WorkoutStore.shared.load().last { $0.template == template }
        guard let l = last else { return }
        exercises = l.exercises.map { ex in
            var copy = ExerciseEntry(name: ex.name)
            copy.sets = ex.sets.map { SetEntry(reps: $0.reps, weight: $0.weight, units: $0.units) }
            return copy
        }
    }

    func finish() {
        guard let template = selectedTemplate else { return }
        let duration = startTime.map { Date().timeIntervalSince($0) }
        let session = WorkoutSession(date: Date(), template: template, exercises: exercises, duration: duration)
        WorkoutStore.shared.add(session)

        // Optional, fire-and-forget HealthKit save (inline so we don't depend on HealthKitManager).
        #if canImport(HealthKit)
        Task {
            if HKHealthStore.isHealthDataAvailable() {
                let store = HKHealthStore()
                // Best-effort authorization
                try? await store.requestAuthorization(toShare: [HKObjectType.workoutType()], read: [])
                let start = session.date
                let end = session.duration.map { start.addingTimeInterval($0) } ?? start
                let workout = HKWorkout(activityType: .functionalStrengthTraining, start: start, end: end)
                try? await store.save(workout)
            }
        }
        #endif

        reset()
    }

    func reset() {
        selectedTemplate = nil
        isLogging = false
        exercises = []
        startTime = nil
    }
}
