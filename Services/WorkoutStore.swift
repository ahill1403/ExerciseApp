import Foundation

final class WorkoutStore {
    static let shared = WorkoutStore()
    private let key = "workoutHistory"
    
    func load() -> [WorkoutSession] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([WorkoutSession].self, from: data)) ?? []
    }
    
    func add(_ session: WorkoutSession) {
        var items = load()
        items.append(session)
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
    
    func workoutsThisWeek(firstWeekday: Int = 1) -> Int {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = firstWeekday // 1 = Sunday
        let today = Date()
        let weekday = cal.component(.weekday, from: today)
        let delta = (weekday - firstWeekday + 7) % 7
        let startOfWeek = cal.startOfDay(for: cal.date(byAdding: .day, value: -delta, to: today)!)
        return load().filter { $0.date >= startOfWeek }.count
    }
    
    func currentStreakDays() -> Int {
        let cal = Calendar(identifier: .gregorian)
        let all = load().map { cal.startOfDay(for: $0.date) }
        let allByDay = Dictionary(grouping: all, by: { $0 })
        var streak = 0
        var day = cal.startOfDay(for: Date())
        while allByDay[day] != nil {
            streak += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return streak
    }
    
    func lastWorkoutDate() -> Date? {
        load().sorted(by: { $0.date > $1.date }).first?.date
    }
}
