//
//  WorkoutModels.swift
//  AtlasFit
//
//  Created by Aaron Hill on 9/11/25.
//

import Foundation

struct SetEntry: Codable, Identifiable, Hashable {
    let id: UUID = UUID()
    var reps: Int
    var weight: Double
    var units: Units
}

struct ExerciseEntry: Codable, Identifiable, Hashable {
    let id: UUID = UUID()
    var name: String
    var sets: [SetEntry] = []
}

struct WorkoutSession: Codable, Identifiable, Hashable {
    let id: UUID = UUID()
    var date: Date
    var template: String
    var exercises: [ExerciseEntry]
    var duration: TimeInterval? // seconds

    var totalSets: Int { exercises.reduce(0) { $0 + $1.sets.count } }
    var totalVolume: Double {
        exercises.flatMap { $0.sets }.reduce(0) { $0 + ($1.weight * Double($1.reps)) }
    }
}
