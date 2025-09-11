//
//  ProgressViewModel.swift
//  AtlasFit
//
//  Created by Aaron Hill on 9/11/25.
//

import Foundation

@MainActor
final class ProgressViewModel: ObservableObject {
    @Published private(set) var sessions: [WorkoutSession] = []
    @Published private(set) var workoutsThisWeek: Int = 0
    @Published private(set) var streakDays: Int = 0
    @Published private(set) var lastWorkout: Date?

    init() {
        refresh()
    }

    func refresh() {
        sessions = WorkoutStore.shared.load().sorted(by: { $0.date > $1.date })
        workoutsThisWeek = WorkoutStore.shared.workoutsThisWeek()
        streakDays = WorkoutStore.shared.currentStreakDays()
        lastWorkout = WorkoutStore.shared.lastWorkoutDate()
    }
}
