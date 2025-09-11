//
//  Models.swift
//  AtlasFit
//
//  Created by Aaron Hill on 9/11/25.
//

import Foundation

enum FitnessGoal: String, Codable, CaseIterable, Identifiable {
    case general = "General Fitness", strength = "Strength", weight = "Weight Management", mobility = "Mobility"
    var id: String { rawValue }
}

enum TrainingExperience: String, Codable, CaseIterable, Identifiable {
    case novice = "Novice", intermediate = "Intermediate", advanced = "Advanced"
    var id: String { rawValue }
}

enum Units: String, Codable, CaseIterable, Identifiable { case lbs = "lbs", kgs = "kgs"; var id: String { rawValue } }
enum Gender: String, Codable, CaseIterable, Identifiable { case female = "Female", male = "Male", other = "Other"; var id: String { rawValue } }

struct OnboardingData {
    var goal: FitnessGoal = .general
    var experience: TrainingExperience = .novice
    var daysPerWeek: Int = 3
    var reminderTime: Date = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date())!
    var wantsNotifications: Bool = true

    var gender: Gender = .other
    var age: Int = 25
    var heightInCm: Double = 175
    var weight: Double = 170
    var units: Units = .lbs
}

struct UserProfile: Codable {
    var createdAt: Date
    var goal: FitnessGoal
    var experience: TrainingExperience
    var daysPerWeek: Int
    var reminderTime: Date?
    var gender: Gender
    var age: Int
    var heightInCm: Double
    var weight: Double
    var units: Units
}
