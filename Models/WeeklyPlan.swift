import Foundation

/// Simple per-week plan: 1=Sun … 7=Sat → selected focus areas for that day
struct WeeklyPlan: Codable, Equatable {
    var days: [Int: [String]] = [:]

    mutating func set(_ areas: [FitnessArea], for day: Int) {
        var names: [String] = []
        for area in areas {
            let name = area.displayName
            if !names.contains(name) {
                names.append(name)
            }
        }
        days[day] = names.isEmpty ? nil : names
    }

    func focusAreas(for day: Int) -> [FitnessArea] {
        (days[day] ?? []).compactMap(FitnessArea.init(displayName:))
    }

    var isEmpty: Bool {
        days.values.allSatisfy { $0.isEmpty }
    }
}

final class PlannerStore {
    static let shared = PlannerStore()
    private let key = "weeklyPlan"

    func load() -> WeeklyPlan {
        guard let data = UserDefaults.standard.data(forKey: key),
              let plan = try? JSONDecoder().decode(WeeklyPlan.self, from: data) else { return WeeklyPlan() }
        return plan
    }

    func save(_ plan: WeeklyPlan) {
        if let data = try? JSONEncoder().encode(plan) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    /// Weekdays with at least one planned focus area.
    func selectedWeekdays(from plan: WeeklyPlan) -> [Int] {
        plan.days.keys.sorted()
    }

    /// Evenly space training days across the week for a given goal count.
    /// e.g., 3 → Mon/Wed/Fri (2,4,6)
    func evenlySpacedWeekdays(goal: Int) -> [Int] {
        guard goal > 0 else { return [] }
        let candidates = [2,3,4,5,6,7,1] // Mon..Sun preference
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
                if secondary != primary { focus.append(secondary) }
            } else if primary != .mobility && mobilityExperience == .novice {
                focus.append(.mobility)
            }

            if profile.goal == .weight && !focus.contains(.neat) {
                focus.append(.neat)
            }

            plan.set(focus, for: day)
        }

        // Ensure at least one mobility-focused day for recovery
        let hasMobility = plan.days.values.contains { $0.contains(FitnessArea.mobility.displayName) }
        if !hasMobility, let firstDay = weekdays.first {
            var focus = plan.focusAreas(for: firstDay)
            focus.append(.mobility)
            plan.set(focus, for: firstDay)
        }

        return plan
    }

    // MARK: - Helpers

    private func prioritizedAreas(for profile: UserProfile) -> [FitnessArea] {
        let goalAreas = goalSequence(for: profile.goal)
        var ordered = [FitnessArea]()
        var seen = Set<FitnessArea>()
        for area in goalAreas {
            if seen.insert(area).inserted { ordered.append(area) }
        }
        for area in FitnessArea.allCases where !seen.contains(area) {
            ordered.append(area)
        }

        let baseIndex = Dictionary(uniqueKeysWithValues: ordered.enumerated().map { ($1, $0) })
        return ordered.sorted { lhs, rhs in
            let lhsExp = profile.experienceByArea[lhs] ?? profile.experience
            let rhsExp = profile.experienceByArea[rhs] ?? profile.experience
            let lhsKey = (lhsExp.priorityWeight, baseIndex[lhs] ?? Int.max)
            let rhsKey = (rhsExp.priorityWeight, baseIndex[rhs] ?? Int.max)
            return lhsKey < rhsKey
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

private extension TrainingExperience {
    var priorityWeight: Int {
        switch self {
        case .novice: return 0
        case .intermediate: return 1
        case .advanced: return 2
        }
    }
}

extension FitnessArea {
    init?(displayName: String) {
        guard let match = FitnessArea.allCases.first(where: { $0.displayName == displayName }) else { return nil }
        self = match
    }
}
