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

enum FitnessArea: String, Codable, CaseIterable, Identifiable {
    case mobility = "Mobility"
    case strength = "Strength"
    case power = "Power"
    case hiit = "HIIT"
    case neat = "NEAT/LISS"

    var id: String { rawValue }

    var displayName: String { rawValue }
}

extension FitnessArea {
    static var defaultExperienceLevels: [FitnessArea: TrainingExperience] {
        Dictionary(uniqueKeysWithValues: Self.allCases.map { ($0, .novice) })
    }
}

enum Units: String, Codable, CaseIterable, Identifiable { case lbs = "lbs", kgs = "kgs"; var id: String { rawValue } }
enum Gender: String, Codable, CaseIterable, Identifiable { case female = "Female", male = "Male", other = "Other"; var id: String { rawValue } }

enum AgeRange: String, Codable, CaseIterable, Identifiable {
    case teens = "13-17"
    case earlyAdults = "18-24"
    case midAdults = "25-34"
    case lateAdults = "35-44"
    case prime = "45-54"
    case masters = "55-64"
    case activeAging = "65+"

    var id: String { rawValue }
    var displayName: String { rawValue }
}

struct OnboardingData {
    var goal: FitnessGoal = .general
    var experience: TrainingExperience = .novice
    var experienceByArea: [FitnessArea: TrainingExperience] = FitnessArea.defaultExperienceLevels
    var daysPerWeek: Int = 3
    var minutesPerDay: Int = 45
    var reminderTime: Date = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date())!
    var wantsNotifications: Bool = true

    var gender: Gender = .other
    var ageRange: AgeRange = .midAdults
    var heightInCm: Double = 175
    var weight: Double = 170
    var units: Units = .lbs
}

struct UserProfile: Codable {
    var createdAt: Date
    var goal: FitnessGoal
    var experience: TrainingExperience
    var experienceByArea: [FitnessArea: TrainingExperience] = FitnessArea.defaultExperienceLevels
    var daysPerWeek: Int
    var minutesPerDay: Int = 45
    var reminderTime: Date?
    var gender: Gender
    var ageRange: AgeRange = .midAdults
    var heightInCm: Double
    var weight: Double
    var units: Units
}
