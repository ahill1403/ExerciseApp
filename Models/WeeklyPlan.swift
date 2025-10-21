import Foundation

/// Weekly plan keyed by weekday (1 = Sunday … 7 = Saturday).
struct WeeklyPlan: Codable, Equatable {
    struct DayPlan: Codable, Equatable {
        var focusAreas: [FitnessArea]
        var workoutIDs: [String]

        init(focusAreas: [FitnessArea] = [], workoutIDs: [String] = []) {
            self.focusAreas = DayPlan.normalize(areas: focusAreas)
            self.workoutIDs = DayPlan.normalize(ids: workoutIDs)
        }

        var isEmpty: Bool { focusAreas.isEmpty && workoutIDs.isEmpty }

        private static func normalize(areas: [FitnessArea]) -> [FitnessArea] {
            var seen = Set<FitnessArea>()
            var ordered: [FitnessArea] = []
            for area in areas {
                if seen.insert(area).inserted {
                    ordered.append(area)
                }
            }
            return ordered
        }

        private static func normalize(ids: [String]) -> [String] {
            var seen = Set<String>()
            var ordered: [String] = []
            for id in ids where !id.isEmpty {
                if seen.insert(id).inserted {
                    ordered.append(id)
                }
            }
            return ordered
        }

        func addingFocus(_ area: FitnessArea) -> DayPlan {
            DayPlan(focusAreas: focusAreas + [area], workoutIDs: workoutIDs)
        }

        func removingFocus(_ area: FitnessArea) -> DayPlan {
            DayPlan(focusAreas: focusAreas.filter { $0 != area }, workoutIDs: workoutIDs)
        }

        func addingWorkout(_ id: String) -> DayPlan {
            DayPlan(focusAreas: focusAreas, workoutIDs: workoutIDs + [id])
        }

        func removingWorkout(_ id: String) -> DayPlan {
            DayPlan(focusAreas: focusAreas, workoutIDs: workoutIDs.filter { $0 != id })
        }

        func replacingWorkouts(_ ids: [String]) -> DayPlan {
            DayPlan(focusAreas: focusAreas, workoutIDs: ids)
        }
    }

    var days: [Int: DayPlan]

    init(days: [Int: DayPlan] = [:]) {
        self.days = days.filter { !$0.value.isEmpty }
    }

    func dayPlan(for day: Int) -> DayPlan? {
        days[day]
    }

    mutating func set(_ areas: [FitnessArea], workouts: [String] = [], for day: Int) {
        set(DayPlan(focusAreas: areas, workoutIDs: workouts), for: day)
    }

    mutating func set(_ plan: DayPlan, for day: Int) {
        if plan.isEmpty {
            days.removeValue(forKey: day)
        } else {
            days[day] = plan
        }
    }

    mutating func addFocus(_ area: FitnessArea, to day: Int) {
        let updated = (dayPlan(for: day) ?? DayPlan()).addingFocus(area)
        set(updated, for: day)
    }

    mutating func removeFocus(_ area: FitnessArea, from day: Int) {
        guard let existing = dayPlan(for: day) else { return }
        set(existing.removingFocus(area), for: day)
    }

    func focusAreas(for day: Int) -> [FitnessArea] {
        dayPlan(for: day)?.focusAreas ?? []
    }

    func workoutIDs(for day: Int) -> [String] {
        dayPlan(for: day)?.workoutIDs ?? []
    }

    mutating func addWorkout(_ id: String, to day: Int) {
        guard !id.isEmpty else { return }
        let updated = (dayPlan(for: day) ?? DayPlan()).addingWorkout(id)
        set(updated, for: day)
    }

    mutating func removeWorkout(_ id: String, from day: Int) {
        guard let existing = dayPlan(for: day) else { return }
        set(existing.removingWorkout(id), for: day)
    }

    mutating func setWorkouts(_ ids: [String], for day: Int) {
        let updated = (dayPlan(for: day) ?? DayPlan()).replacingWorkouts(ids)
        set(updated, for: day)
    }

    var isEmpty: Bool {
        days.values.allSatisfy { $0.isEmpty }
    }
}

extension WeeklyPlan {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let decoded = try? container.decode([Int: DayPlan].self) {
            self.init(days: decoded)
            return
        }

        if let legacy = try? container.decode([Int: [String]].self) {
            var mapped: [Int: DayPlan] = [:]
            for (day, values) in legacy {
                let areas = values.compactMap(FitnessArea.init(displayName:))
                let dayPlan = DayPlan(focusAreas: areas)
                if !dayPlan.isEmpty {
                    mapped[day] = dayPlan
                }
            }
            self.init(days: mapped)
            return
        }

        self.init()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(days)
    }
}

final class PlannerStore {
    static let shared = PlannerStore()
    private let key = "weeklyPlan"

    func load() -> WeeklyPlan {
        guard let data = UserDefaults.standard.data(forKey: key),
              let plan = try? JSONDecoder().decode(WeeklyPlan.self, from: data)
        else { return WeeklyPlan() }
        return plan
    }

    func save(_ plan: WeeklyPlan) {
        if let data = try? JSONEncoder().encode(plan) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    /// Weekdays with at least one planned focus area or workout.
    func selectedWeekdays(from plan: WeeklyPlan) -> [Int] {
        plan.days
            .filter { !$0.value.isEmpty }
            .map(\.key)
            .sorted()
    }

    /// Evenly space training days across the week for a given goal count.
    /// e.g., 3 → Mon/Wed/Fri (2,4,6)
    func evenlySpacedWeekdays(goal: Int) -> [Int] {
        guard goal > 0 else { return [] }
        let candidates = [2, 3, 4, 5, 6, 7, 1] // Mon..Sun preference
        if goal >= candidates.count { return Array(1...7) }
        let stride = Double(candidates.count) / Double(goal)
        return (0..<goal).map { candidates[Int(round(Double($0) * stride)) % candidates.count] }
    }

    func recommendedPlan(for profile: UserProfile) -> WeeklyPlan {
        let weekdays = evenlySpacedWeekdays(goal: profile.daysPerWeek)
        guard !weekdays.isEmpty else { return WeeklyPlan() }

        let rotation = prioritizedAreas(for: profile)
        var plan = WeeklyPlan()
        for (index, day) in weekdays.enumerated() {
            let primary = rotation[index % rotation.count]
            var focus: [FitnessArea] = [primary]

            let mobilityExperience = profile.experienceByArea[.mobility] ?? profile.experience
            if profile.daysPerWeek >= 4 {
                let secondary = rotation[(index + 1) % rotation.count]
                if secondary != primary {
                    focus.append(secondary)
                }
            } else if primary != .mobility && mobilityExperience == .novice {
                focus.append(.mobility)
            }

            if profile.goal == .weight && !focus.contains(.neat) {
                focus.append(.neat)
            }

            let workouts = recommendedWorkouts(for: focus, profile: profile)
            plan.set(focus, workouts: workouts.map(\.id), for: day)
        }

        let hasMobility = plan.days.values.contains { $0.focusAreas.contains(.mobility) }
        if !hasMobility, let firstDay = weekdays.first {
            var existing = plan.dayPlan(for: firstDay) ?? WeeklyPlan.DayPlan()
            existing = existing.addingFocus(.mobility)
            let additional = recommendedWorkouts(
                for: [.mobility],
                profile: profile,
                excluding: Set(existing.workoutIDs)
            )
            existing = existing.replacingWorkouts(existing.workoutIDs + additional.map(\.id))
            plan.set(existing, for: firstDay)
        }

        return plan
    }

    // MARK: - Helpers

    private func prioritizedAreas(for profile: UserProfile) -> [FitnessArea] {
        let goalAreas = goalSequence(for: profile.goal)
        var ordered = [FitnessArea]()
        var seen = Set<FitnessArea>()
        for area in goalAreas where seen.insert(area).inserted {
            ordered.append(area)
        }
        for area in FitnessArea.allCases where !seen.contains(area) {
            ordered.append(area)
        }

        let baseIndex = Dictionary(uniqueKeysWithValues: ordered.enumerated().map { ($1, $0) })
        return ordered.sorted { lhs, rhs in
            let lhsExp = profile.experienceByArea[lhs] ?? profile.experience
            let rhsExp = profile.experienceByArea[rhs] ?? profile.experience
            let lhsKey = (lhsExp.levelIndex, baseIndex[lhs] ?? Int.max)
            let rhsKey = (rhsExp.levelIndex, baseIndex[rhs] ?? Int.max)
            return lhsKey < rhsKey
        }
    }

    private func recommendedWorkouts(for focus: [FitnessArea], profile: UserProfile, excluding existing: Set<String> = []) -> [WorkoutDefinition] {
        var used = existing
        var selections: [WorkoutDefinition] = []
        for area in focus {
            let experience = profile.experienceByArea[area] ?? profile.experience
            let count = recommendedCount(for: area, minutes: profile.minutesPerDay)
            let picks = WorkoutCatalog.shared.sampleWorkouts(
                for: area,
                experience: experience,
                count: count,
                excluding: used
            )
            selections.append(contentsOf: picks)
            used.formUnion(picks.map(\.id))
        }
        return selections
    }

    private func recommendedCount(for area: FitnessArea, minutes: Int) -> Int {
        switch area {
        case .strength: return minutes >= 60 ? 5 : 4
        case .power: return 3
        case .mobility: return minutes >= 45 ? 4 : 3
        case .hiit: return 3
        case .neat: return minutes >= 45 ? 3 : 2
        }
    }

    private func goalSequence(for goal: FitnessGoal) -> [FitnessArea] {
        switch goal {
        case .general:
            return [.strength, .mobility, .neat, .strength, .hiit, .power]
        case .strength:
            return [.strength, .power, .strength, .mobility, .strength, .neat]
        case .weight:
            return [.hiit, .neat, .strength, .hiit, .mobility, .neat]
        case .mobility:
            return [.mobility, .strength, .mobility, .neat, .mobility, .hiit]
        }
    }
}

extension FitnessArea {
    init?(displayName: String) {
        let normalized = displayName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        for area in FitnessArea.allCases {
            if area.aliases.contains(normalized) {
                self = area
                return
            }
        }
        return nil
    }
}
