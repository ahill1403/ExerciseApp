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
    @Published private(set) var planSuggestion: PlanSuggestion?

    // Sheets
    @Published var showAddExercise = false
    @Published var newExerciseName = ""

    let templates = [
        "Full Body",
        "Upper Body",
        "Lower Body",
        "Push",
        "Pull",
        "Legs",
        "Core",
        "Mobility Flow",
        "Quick Interval Blast",
        "Power Complex",
        "Steady Walk",
        "Custom"
    ]

    private let templateMapping: [FitnessArea: [String]] = [
        .strength: ["Full Body", "Upper Body", "Lower Body", "Push", "Pull", "Legs"],
        .mobility: ["Mobility Flow", "Full Body"],
        .power: ["Power Complex", "Full Body"],
        .hiit: ["Quick Interval Blast", "Full Body"],
        .neat: ["Steady Walk", "Mobility Flow"]
    ]

    private let calendar = Calendar.current

    struct PlanSuggestion {
        let day: Int
        let offset: Int
        let areas: [FitnessArea]
        let templates: [String]

        var isToday: Bool { offset == 0 }
    }

    init() {
        refreshPlanSuggestion()
    }
    
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

    func refreshPlanSuggestion(referenceDate: Date = Date()) {
        let plan = PlannerStore.shared.load()
        guard let next = nextScheduledDay(in: plan, from: referenceDate) else {
            planSuggestion = nil
            return
        }

        let areas = plan.focusAreas(for: next.day)
        guard !areas.isEmpty else {
            planSuggestion = nil
            return
        }

        let templates = recommendedTemplates(for: areas)
        planSuggestion = PlanSuggestion(day: next.day, offset: next.offset, areas: areas, templates: templates)
    }

    func startRecommendedTemplate() {
        guard let template = planSuggestion?.templates.first else { return }
        start(template: template)
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
                try? await store.requestAuthorization(toShare: [HKObjectType.workoutType()], read: [])
                
                let start = session.date
                let end   = session.duration.map { start.addingTimeInterval($0) } ?? start
                
                let config = HKWorkoutConfiguration()
                config.activityType = .functionalStrengthTraining
                
                let builder = HKWorkoutBuilder(healthStore: store, configuration: config, device: nil)
                try? await builder.beginCollection(at: start)
                try? await builder.endCollection(at: end)
                _ = try? await builder.finishWorkout()
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
        refreshPlanSuggestion()
    }

    private func nextScheduledDay(in plan: WeeklyPlan, from date: Date) -> (day: Int, offset: Int)? {
        let today = calendar.component(.weekday, from: date)
        for offset in 0..<7 {
            let day = ((today - 1 + offset) % 7) + 1
            if !plan.focusAreas(for: day).isEmpty {
                return (day, offset)
            }
        }
        return nil
    }

    private func recommendedTemplates(for areas: [FitnessArea]) -> [String] {
        var options: [String] = []
        for area in areas {
            if let mapped = templateMapping[area] {
                options.append(contentsOf: mapped)
            }
        }
        if options.isEmpty {
            options.append("Full Body")
        }
        var unique: [String] = []
        for option in options {
            if !unique.contains(option) {
                unique.append(option)
            }
        }
        return unique
    }
}
