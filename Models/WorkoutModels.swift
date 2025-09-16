//
//  WorkoutModels.swift
//  AtlasFit
//
//  Created by Aaron Hill on 9/11/25.
//

import Foundation

struct SetEntry: Codable, Identifiable, Hashable {
    let id: UUID
    var reps: Int
    var weight: Double
    var units: Units

    init(id: UUID = UUID(), reps: Int, weight: Double, units: Units) {
        self.id = id
        self.reps = reps
        self.weight = weight
        self.units = units
    }
}

struct ExerciseEntry: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var sets: [SetEntry]

    init(id: UUID = UUID(), name: String, sets: [SetEntry] = []) {
        self.id = id
        self.name = name
        self.sets = sets
    }
}

struct WorkoutSession: Codable, Identifiable, Hashable {
    let id: UUID
    var date: Date
    var template: String
    var exercises: [ExerciseEntry]
    var duration: TimeInterval? // seconds

    init(
        id: UUID = UUID(),
        date: Date,
        template: String,
        exercises: [ExerciseEntry],
        duration: TimeInterval?
    ) {
        self.id = id
        self.date = date
        self.template = template
        self.exercises = exercises
        self.duration = duration
    }

    var totalSets: Int { exercises.reduce(0) { $0 + $1.sets.count } }
    var totalVolume: Double {
        exercises.flatMap { $0.sets }.reduce(0) { $0 + ($1.weight * Double($1.reps)) }
    }
}
