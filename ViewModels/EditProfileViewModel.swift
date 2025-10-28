//
//  EditProfileViewModel.swift
//  REPS
//
//  Created by Aaron Hill on 9/11/25.
//

import Foundation
import SwiftUI

@MainActor
final class EditProfileViewModel: ObservableObject {
    // MARK: - Editable fields
    @Published var goal: FitnessGoal = .general
    @Published var experience: TrainingExperience = .beginner
    @Published var experienceByArea: [FitnessArea: TrainingExperience] = FitnessArea.defaultExperienceLevels
    @Published var daysPerWeek: Int = 3
    @Published var minutesPerDay: Int = 45

    @Published var wantsNotifications: Bool = false
    @Published var reminderTime: Date = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: .now) ?? .now

    @Published var gender: Gender = .other
    @Published var ageRange: AgeRange = .midAdults
    @Published var heightInCm: Double = 175
    @Published var weight: Double = 170
    @Published var units: Units = .lbs

    // MARK: - Alerts
    @Published var alertMessage: String?

    init() {
        loadFromStorage()
    }

    // MARK: - Load / Save
    func loadFromStorage() {
        if let data = UserDefaults.standard.data(forKey: "userProfile"),
           let profile = try? JSONDecoder().decode(UserProfile.self, from: data) {
            goal = profile.goal
            experience = profile.experience
            experienceByArea = FitnessArea.defaultExperienceLevels.merging(profile.experienceByArea) { _, new in new }
            daysPerWeek = profile.daysPerWeek
            minutesPerDay = profile.minutesPerDay
            if let t = profile.reminderTime {
                wantsNotifications = true
                reminderTime = t
            } else {
                wantsNotifications = false
            }
            gender = profile.gender
            ageRange = profile.ageRange
            heightInCm = profile.heightInCm
            weight = profile.weight
            units = profile.units
        }
    }

    func save() {
        let normalizedExperience = FitnessArea.defaultExperienceLevels.merging(experienceByArea) { _, new in new }

        let profile = UserProfile(
            createdAt: .now,
            goal: goal,
            experience: experience,
            experienceByArea: normalizedExperience,
            daysPerWeek: daysPerWeek,
            minutesPerDay: minutesPerDay,
            reminderTime: wantsNotifications ? reminderTime : nil,
            gender: gender,
            ageRange: ageRange,
            heightInCm: heightInCm,
            weight: weight,
            units: units
        )

        if let encoded = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(encoded, forKey: "userProfile")
        }

        if wantsNotifications {
            ensureNotificationPermissionThenSchedule()
        } else {
            NotificationManager.shared.cancelReminders()
        }
    }

    // MARK: - Notifications
    private func ensureNotificationPermissionThenSchedule() {
        NotificationManager.shared.authStatus { [weak self] status in
            guard let self else { return }
            switch status {
            case .authorized:
                NotificationManager.shared.scheduleWeeklyReminders(time: self.reminderTime, daysPerWeek: self.daysPerWeek)
            case .notDetermined:
                NotificationManager.shared.requestAuthorization { ok in
                    Task { @MainActor in
                        if ok {
                            NotificationManager.shared.scheduleWeeklyReminders(time: self.reminderTime, daysPerWeek: self.daysPerWeek)
                        } else {
                            self.wantsNotifications = false
                            self.alertMessage = "Notifications were not enabled."
                        }
                    }
                }
            case .denied:
                Task { @MainActor in
                    self.wantsNotifications = false
                    self.alertMessage = "Notifications are disabled. Enable them in Settings to receive reminders."
                }
            }
        }
    }
}
