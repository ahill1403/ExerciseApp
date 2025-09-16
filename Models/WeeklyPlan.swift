import Foundation

/// Simple per-week plan: 1=Sun … 7=Sat → selected focus areas for that day
struct WeeklyPlan: Codable, Equatable {
    var days: [Int: [String]] = [:]
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
}
