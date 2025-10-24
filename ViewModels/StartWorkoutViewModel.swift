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

    struct TemplateInfo: Identifiable, Hashable {
        let id = UUID()
        let name: String
        let focus: String
        let duration: String
        let equipment: String
        let summary: String
    }

    let templates: [TemplateInfo] = [
        TemplateInfo(
            name: "Foundations Strength",
            focus: "Strength",
            duration: "45 min",
            equipment: "Dumbbells + bench",
            summary: "Balanced pushes, pulls and core finish to build full-body strength."
        ),
        TemplateInfo(
            name: "Upper Body Push",
            focus: "Chest & Shoulders",
            duration: "35 min",
            equipment: "Bench + dumbbells",
            summary: "Superset pressing variations with accessory triceps work."
        ),
        TemplateInfo(
            name: "Lower Body Strength",
            focus: "Legs & Glutes",
            duration: "40 min",
            equipment: "Barbell or dumbbells",
            summary: "Squat, hinge and lunge sequence to drive lower-body power."
        ),
        TemplateInfo(
            name: "Mobility Reset",
            focus: "Mobility",
            duration: "20 min",
            equipment: "Mat + foam roller",
            summary: "Gentle flow to open tight hips, spine and shoulders."
        ),
        TemplateInfo(
            name: "Interval Ignite",
            focus: "HIIT",
            duration: "25 min",
            equipment: "Treadmill or open space",
            summary: "Alternating sprint and recovery blocks for conditioning."
        ),
        TemplateInfo(
            name: "Power Circuit",
            focus: "Explosive Power",
            duration: "30 min",
            equipment: "Kettlebell + medicine ball",
            summary: "Dynamic jumps and loaded power drills to train speed."
        ),
        TemplateInfo(
            name: "Recovery Walk",
            focus: "NEAT / LISS",
            duration: "30 min",
            equipment: "Comfortable shoes",
            summary: "Guided brisk walk with posture resets and breathing cues."
        )
    ]

    private let templateMapping: [FitnessArea: [String]] = [
        .strength: ["Foundations Strength", "Upper Body Push", "Lower Body Strength"],
        .mobility: ["Mobility Reset"],
        .power: ["Power Circuit", "Foundations Strength"],
        .hiit: ["Interval Ignite"],
        .neat: ["Recovery Walk", "Mobility Reset"]
    ]

    func info(for templateName: String) -> TemplateInfo? {
        templates.first { $0.name == templateName }
    }

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
        if options.isEmpty, let first = templates.first?.name {
            options.append(first)
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
