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
    @Published private(set) var todaysWorkouts: [WorkoutDefinition] = []
    @Published var currentWorkoutIndex: Int = 0
    @Published var completedWorkoutIDs: Set<String> = []
    @Published var workoutsReadyForCompletion: Set<String> = []
    @Published var lastCompletionMessage: String?
    @Published var completedSetIDs: Set<UUID> = []
    @Published private(set) var restDurations: [TimeInterval] = []

    // Sheets
    @Published var showAddExercise = false
    @Published var newExerciseName = ""

    struct TemplateInfo: Identifiable, Hashable {
        let id = UUID()
        let name: String
        let area: FitnessArea
        let focus: String
        let duration: String
        let equipment: String
        let summary: String
    }

    let templates: [TemplateInfo] = [
        TemplateInfo(
            name: "Foundations Strength",
            area: .strength,
            focus: "Strength",
            duration: "45 min",
            equipment: "Dumbbells + bench",
            summary: "Balanced pushes, pulls and core finish to build full-body strength."
        ),
        TemplateInfo(
            name: "Upper Body Push",
            area: .strength,
            focus: "Chest & Shoulders",
            duration: "35 min",
            equipment: "Bench + dumbbells",
            summary: "Superset pressing variations with accessory triceps work."
        ),
        TemplateInfo(
            name: "Lower Body Strength",
            area: .strength,
            focus: "Legs & Glutes",
            duration: "40 min",
            equipment: "Barbell or dumbbells",
            summary: "Squat, hinge and lunge sequence to drive lower-body power."
        ),
        TemplateInfo(
            name: "Mobility Reset",
            area: .mobility,
            focus: "Mobility",
            duration: "20 min",
            equipment: "Mat + foam roller",
            summary: "Gentle flow to open tight hips, spine and shoulders."
        ),
        TemplateInfo(
            name: "Interval Ignite",
            area: .hiit,
            focus: "HIIT",
            duration: "25 min",
            equipment: "Treadmill or open space",
            summary: "Alternating sprint and recovery blocks for conditioning."
        ),
        TemplateInfo(
            name: "Power Circuit",
            area: .power,
            focus: "Explosive Power",
            duration: "30 min",
            equipment: "Kettlebell + medicine ball",
            summary: "Dynamic jumps and loaded power drills to train speed."
        ),
        TemplateInfo(
            name: "Recovery Walk",
            area: .neat,
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
        completedWorkoutIDs = []
        completedSetIDs = []
        workoutsReadyForCompletion = []
        restDurations = []
        currentWorkoutIndex = 0
        setTargetCache = [:]

        let planWorkouts = todaysPlanWorkouts()
        if !planWorkouts.isEmpty {
            todaysWorkouts = planWorkouts
        } else {
            todaysWorkouts = fallbackWorkouts(for: template)
        }
        bindExercisesToWorkouts()
    }

    func addExercise() {
        let name = newExerciseName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let entry = ExerciseEntry(name: name)
        exercises.append(entry)

        let customDefinition = WorkoutDefinition(
            id: "custom-\(UUID().uuidString)",
            name: name,
            area: .strength,
            equipment: "Custom entry",
            summary: "Track your own movement."
        )
        todaysWorkouts.append(customDefinition)
        workoutExerciseLookup[customDefinition.id] = entry.id
        currentWorkoutIndex = max(todaysWorkouts.count - 1, 0)
        completedWorkoutIDs.remove(customDefinition.id)
        workoutsReadyForCompletion.remove(customDefinition.id)
        setTargetCache.removeValue(forKey: customDefinition.id)
        newExerciseName = ""
        showAddExercise = false
    }

    @discardableResult
    func addSet(to exerciseID: UUID, reps: Int, weight: Double, units: Units) -> SetEntry? {
        guard let idx = exercises.firstIndex(where: { $0.id == exerciseID }) else { return nil }
        let entry = SetEntry(reps: reps, weight: weight, units: units)
        exercises[idx].sets.append(entry)
        completedSetIDs.insert(entry.id)

        if let workoutID = workoutID(forExercise: exerciseID) {
            reevaluateCompletion(for: workoutID)
        }
        return entry
    }

    func removeExercise(_ exerciseID: UUID) {
        if let entry = exercises.first(where: { $0.id == exerciseID }) {
            completedSetIDs.subtract(entry.sets.map(\.id))
        }
        let associatedWorkoutID = workoutExerciseLookup.first { $0.value == exerciseID }?.key
        exercises.removeAll { $0.id == exerciseID }
        if let associatedWorkoutID {
            workoutsReadyForCompletion.remove(associatedWorkoutID)
            completedWorkoutIDs.remove(associatedWorkoutID)
            workoutExerciseLookup[associatedWorkoutID] = nil
            setTargetCache.removeValue(forKey: associatedWorkoutID)
        }
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
        exercises = l.exercises
        completedSetIDs = []
        workoutsReadyForCompletion = []
        restDurations = []
        setTargetCache = [:]
        bindExercisesToWorkouts()
    }

    func finish() {
        guard let template = selectedTemplate else { return }
        let duration = startTime.map { Date().timeIntervalSince($0) }
        let session = WorkoutSession(date: Date(), template: template, exercises: exercises, duration: duration, restDurations: restDurations)
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
        
        
        lastCompletionMessage = buildCompletionMessage(from: session)

        reset(clearCompletionMessage: false)
    }

    func reset(clearCompletionMessage: Bool = true) {
        selectedTemplate = nil
        isLogging = false
        exercises = []
        startTime = nil
        todaysWorkouts = []
        completedWorkoutIDs = []
        currentWorkoutIndex = 0
        workoutExerciseLookup = [:]
        completedSetIDs = []
        workoutsReadyForCompletion = []
        restDurations = []
        setTargetCache = [:]
        refreshPlanSuggestion()
        if clearCompletionMessage {
            lastCompletionMessage = nil
        }
    }

    func recordRestDuration(_ duration: TimeInterval) {
        guard duration > 0 else { return }
        restDurations.append(duration)
    }

    func selectWorkout(with id: String) {
        guard let index = todaysWorkouts.firstIndex(where: { $0.id == id }) else { return }
        currentWorkoutIndex = index
    }

    func toggleCompletion(for id: String) {
        guard let index = todaysWorkouts.firstIndex(where: { $0.id == id }) else { return }
        if completedWorkoutIDs.contains(id) {
            completedWorkoutIDs.remove(id)
            currentWorkoutIndex = index
            workoutsReadyForCompletion.remove(id)
        } else {
            completedWorkoutIDs.insert(id)
            workoutsReadyForCompletion.remove(id)
            advanceToNextWorkout(after: index)
        }
    }

    func exercise(for workoutID: String) -> ExerciseEntry? {
        guard let index = exerciseIndex(for: workoutID) else { return nil }
        return exercises[index]
    }

    func exerciseID(for workoutID: String) -> UUID? {
        workoutExerciseLookup[workoutID]
    }

    func sets(for workoutID: String) -> [SetEntry] {
        guard let index = exerciseIndex(for: workoutID) else { return [] }
        return exercises[index].sets
    }

    func isCompleted(_ workoutID: String) -> Bool {
        completedWorkoutIDs.contains(workoutID)
    }

    func isReadyForCompletion(_ workoutID: String) -> Bool {
        workoutsReadyForCompletion.contains(workoutID)
    }

    func isPlannedExercise(_ id: UUID) -> Bool {
        workoutExerciseLookup.values.contains(id)
    }

    func targetSetCount(for workoutID: String) -> Int? {
        plannedSetCount(for: workoutID)
    }

    func workoutID(forSet setID: UUID) -> String? {
        guard let exerciseID = exerciseID(forSet: setID) else { return nil }
        return workoutID(forExercise: exerciseID)
    }

    func toggleSetCompletion(for setID: UUID) {
        let wasCompleted = completedSetIDs.contains(setID)
        if wasCompleted {
            completedSetIDs.remove(setID)
        } else {
            completedSetIDs.insert(setID)
        }

        if let workoutID = workoutID(forSet: setID) {
            reevaluateCompletion(for: workoutID)
        }
    }

    func isSetCompleted(_ setID: UUID) -> Bool {
        completedSetIDs.contains(setID)
    }

    func removeSet(from exerciseID: UUID, setID: UUID) {
        guard let exerciseIndex = exercises.firstIndex(where: { $0.id == exerciseID }) else { return }
        exercises[exerciseIndex].sets.removeAll { $0.id == setID }
        completedSetIDs.remove(setID)

        if let workoutID = workoutID(forExercise: exerciseID) {
            reevaluateCompletion(for: workoutID)
        }
    }

    func finalizeReadyWorkout(_ workoutID: String) {
        guard workoutsReadyForCompletion.contains(workoutID),
              let index = todaysWorkouts.firstIndex(where: { $0.id == workoutID }) else { return }

        workoutsReadyForCompletion.remove(workoutID)
        if !completedWorkoutIDs.contains(workoutID) {
            completedWorkoutIDs.insert(workoutID)
        }
        advanceToNextWorkout(after: index)
    }

    // MARK: - Private

    private var workoutExerciseLookup: [String: UUID] = [:]
    private var setTargetCache: [String: Int] = [:]

    private func workoutID(forExercise exerciseID: UUID) -> String? {
        workoutExerciseLookup.first { $0.value == exerciseID }?.key
    }

    private func exerciseID(forSet setID: UUID) -> UUID? {
        exercises.first(where: { $0.sets.contains(where: { $0.id == setID }) })?.id
    }

    private func plannedSetCount(for workoutID: String) -> Int? {
        if let cached = setTargetCache[workoutID] {
            return cached
        }

        if let workout = todaysWorkouts.first(where: { $0.id == workoutID }) ?? WorkoutCatalog.shared.workout(for: workoutID),
           let recommended = workout.recommendedSetCount {
            setTargetCache[workoutID] = recommended
            return recommended
        }

        return nil
    }

    private func reevaluateCompletion(for workoutID: String) {
        guard let index = todaysWorkouts.firstIndex(where: { $0.id == workoutID }),
              let exercise = exercise(for: workoutID) else { return }

        let hasSets = !exercise.sets.isEmpty
        let allCompleted = hasSets && exercise.sets.allSatisfy { completedSetIDs.contains($0.id) }

        let meetsTarget: Bool
        if let target = plannedSetCount(for: workoutID) {
            meetsTarget = exercise.sets.count >= target
        } else {
            meetsTarget = hasSets
        }

        if allCompleted && meetsTarget {
            if !completedWorkoutIDs.contains(workoutID) {
                workoutsReadyForCompletion.insert(workoutID)
            }
        } else if completedWorkoutIDs.contains(workoutID) {
            completedWorkoutIDs.remove(workoutID)
            currentWorkoutIndex = index
            workoutsReadyForCompletion.remove(workoutID)
        } else {
            workoutsReadyForCompletion.remove(workoutID)
        }
    }

    private func todaysPlanWorkouts(date: Date = Date()) -> [WorkoutDefinition] {
        let plan = PlannerStore.shared.load()
        let today = calendar.component(.weekday, from: date)
        let ids = plan.workoutIDs(for: today)
        return WorkoutCatalog.shared.workouts(forIDs: ids)
    }

    private func fallbackWorkouts(for template: String) -> [WorkoutDefinition] {
        guard let info = info(for: template) else { return [] }
        let experience = experience(for: info.area)
        let primary = WorkoutCatalog.shared.sampleWorkouts(for: info.area, experience: experience, count: 4)
        if !primary.isEmpty {
            return primary
        }
        return WorkoutCatalog.shared.allWorkouts(for: info.area, experience: experience)
    }

    private func experience(for area: FitnessArea) -> TrainingExperience {
        if let profile = loadProfile() {
            return profile.experienceByArea[area] ?? profile.experience
        }
        return .beginner
    }

    private func loadProfile() -> UserProfile? {
        guard let data = UserDefaults.standard.data(forKey: "userProfile") else { return nil }
        return try? JSONDecoder().decode(UserProfile.self, from: data)
    }

    private func bindExercisesToWorkouts() {
        setTargetCache = [:]
        var remaining = exercises
        var updated: [ExerciseEntry] = []
        var lookup: [String: UUID] = [:]

        for workout in todaysWorkouts {
            if let index = remaining.firstIndex(where: { $0.name == workout.name }) {
                let entry = remaining.remove(at: index)
                updated.append(entry)
                lookup[workout.id] = entry.id
            } else if let existingID = workoutExerciseLookup[workout.id],
                      let existingIndex = exercises.firstIndex(where: { $0.id == existingID }) {
                let entry = exercises[existingIndex]
                updated.append(entry)
                lookup[workout.id] = entry.id
            } else {
                let entry = ExerciseEntry(name: workout.name)
                updated.append(entry)
                lookup[workout.id] = entry.id
            }
        }

        updated.append(contentsOf: remaining)
        exercises = updated
        workoutExerciseLookup = lookup
        if currentWorkoutIndex >= todaysWorkouts.count {
            currentWorkoutIndex = max(todaysWorkouts.count - 1, 0)
        }
    }

    private func advanceToNextWorkout(after index: Int) {
        let remaining = todaysWorkouts.enumerated().first { idx, workout in
            idx > index && !completedWorkoutIDs.contains(workout.id)
        }

        if let next = remaining?.offset {
            currentWorkoutIndex = next
        } else if let firstIncomplete = todaysWorkouts.enumerated().first(where: { !completedWorkoutIDs.contains($0.element.id) })?.offset {
            currentWorkoutIndex = firstIncomplete
        }
    }

    private func exerciseIndex(for workoutID: String) -> Int? {
        guard let id = workoutExerciseLookup[workoutID] else { return nil }
        return exercises.firstIndex(where: { $0.id == id })
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

    private func buildCompletionMessage(from session: WorkoutSession) -> String {
        let totalSets = session.exercises.reduce(0) { $0 + $1.sets.count }
        let exerciseCount = session.exercises.count

        var messageParts: [String] = []

        if totalSets > 0 {
            messageParts.append("\(totalSets) set\(totalSets == 1 ? "" : "s") logged")
        } else {
            messageParts.append("session saved")
        }

        if exerciseCount > 0 {
            messageParts.append("across \(exerciseCount) exercise\(exerciseCount == 1 ? "" : "s")")
        }

        if let duration = session.duration, duration > 60 {
            let minutes = Int(duration / 60)
            if minutes > 0 {
                messageParts.append("in \(minutes)-minute push")
            }
        }

        let summary = messageParts.joined(separator: " • ")
        let templateName = session.template

        return "Nice work! \(templateName) complete — \(summary). Keep that momentum going!"
    }
}
