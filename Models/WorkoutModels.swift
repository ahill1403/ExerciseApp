//
//  WorkoutModels.swift
//  REPS
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
    var restDurations: [TimeInterval]

    init(
        id: UUID = UUID(),
        date: Date,
        template: String,
        exercises: [ExerciseEntry],
        duration: TimeInterval?,
        restDurations: [TimeInterval] = []
    ) {
        self.id = id
        self.date = date
        self.template = template
        self.exercises = exercises
        self.duration = duration
        self.restDurations = restDurations
    }

    var totalSets: Int { exercises.reduce(0) { $0 + $1.sets.count } }
    var totalVolume: Double {
        exercises.flatMap { $0.sets }.reduce(0) { $0 + ($1.weight * Double($1.reps)) }
    }

    var totalReps: Int {
        exercises.flatMap { $0.sets }.reduce(0) { $0 + $1.reps }
    }

    var averageRestDuration: TimeInterval? {
        guard !restDurations.isEmpty else { return nil }
        let total = restDurations.reduce(0, +)
        return total / Double(restDurations.count)
    }

    private enum CodingKeys: String, CodingKey {
        case id, date, template, exercises, duration, restDurations
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        date = try container.decode(Date.self, forKey: .date)
        template = try container.decode(String.self, forKey: .template)
        exercises = try container.decode([ExerciseEntry].self, forKey: .exercises)
        duration = try container.decodeIfPresent(TimeInterval.self, forKey: .duration)
        restDurations = try container.decodeIfPresent([TimeInterval].self, forKey: .restDurations) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(date, forKey: .date)
        try container.encode(template, forKey: .template)
        try container.encode(exercises, forKey: .exercises)
        try container.encode(duration, forKey: .duration)
        try container.encode(restDurations, forKey: .restDurations)
    }
}
