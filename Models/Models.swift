//
//  Models.swift
//  REPS
//
//  Created by Aaron Hill on 9/11/25.
//

import Foundation

enum FitnessGoal: String, Codable, CaseIterable, Identifiable {
    case general = "General Fitness", strength = "Strength", weight = "Weight Management", mobility = "Mobility"
    var id: String { rawValue }
}

enum TrainingExperience: String, Codable, CaseIterable, Identifiable {
    case beginner = "Beginner", intermediate = "Intermediate", advanced = "Advanced"
    var id: String { rawValue }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)

        if let value = TrainingExperience(rawValue: rawValue) {
            self = value
        } else if rawValue.lowercased() == "novice" {
            self = .beginner
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unexpected training experience value: \(rawValue)"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

enum FitnessArea: String, Codable, CaseIterable, Identifiable {
    case mobility = "Mobility"
    case strength = "Strength"
    case power = "Power"
    case hiit = "HIIT"
    case neat = "NEAT/LISS"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .mobility: return "Mobility & Stretching"
        case .strength: return "Strength Training"
        case .power: return "Power & Athleticism"
        case .hiit: return "Quick Intervals"
        case .neat: return "Steady Cardio"
        }
    }

    /// Case-insensitive aliases so previously stored values still decode correctly.
    var aliases: [String] {
        switch self {
        case .mobility:
            return [rawValue, displayName, "Mobility & Recovery"].map { $0.lowercased() }
        case .strength:
            return [rawValue, displayName].map { $0.lowercased() }
        case .power:
            return [rawValue, displayName, "Explosive Power"].map { $0.lowercased() }
        case .hiit:
            return [rawValue, displayName, "Intervals"].map { $0.lowercased() }
        case .neat:
            return [rawValue, displayName, "NEAT", "Easy Cardio"].map { $0.lowercased() }
        }
    }
}

extension FitnessArea {
    static var defaultExperienceLevels: [FitnessArea: TrainingExperience] {
        Dictionary(uniqueKeysWithValues: Self.allCases.map { ($0, .beginner) })
    }
}

enum Units: String, Codable, CaseIterable, Identifiable { case lbs = "lbs", kgs = "kgs"; var id: String { rawValue } }
enum Gender: String, Codable, CaseIterable, Identifiable {
    case female = "Female"
    case male = "Male"
    case other = "Other"
    case preferNotToSay = "Prefer not to say"
    var id: String { rawValue }
}

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
    var experience: TrainingExperience = .beginner
    var experienceByArea: [FitnessArea: TrainingExperience] = FitnessArea.defaultExperienceLevels
    var daysPerWeek: Int = 3
    var minutesPerDay: Int = 45
    var reminderTime: Date = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date())!
    var wantsNotifications: Bool = true

    var gender: Gender = .preferNotToSay
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

extension TrainingExperience {
    /// Relative order used for filtering catalog workouts and prioritising focus areas.
    var levelIndex: Int {
        switch self {
        case .beginner: return 0
        case .intermediate: return 1
        case .advanced: return 2
        }
    }
}

