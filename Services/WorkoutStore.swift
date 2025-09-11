//
//  WorkoutStore.swift
//  AtlasFit
//
//  Created by Aaron Hill on 9/11/25.
//

import Foundation

final class WorkoutStore {
    static let shared = WorkoutStore()
    private let key = "workoutHistory"

    func load() -> [WorkoutSession] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([WorkoutSession].self, from: data)) ?? []
    }

    func save(_ sessions: [WorkoutSession]) {
        if let data = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func add(_ session: WorkoutSession) {
        var all = load()
        all.append(session)
        save(all)
    }

    // MARK: - Stats
    func workoutsThisWeek() -> Int {
        let all = load()
        let cal = Calendar.current
        let startOfWeek = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) ?? Date()
        return all.filter { $0.date >= startOfWeek }.count
    }

    func currentStreakDays() -> Int {
        let cal = Calendar.current
        let allByDay = Dictionary(grouping: load()) { cal.startOfDay(for: $0.date) }
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
