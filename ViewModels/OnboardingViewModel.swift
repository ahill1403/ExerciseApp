//
//  OnboardingViewModel.swift
//  AtlasFit
//
//  Created by Aaron Hill on 9/11/25.
//

import Foundation
import SwiftUI

@MainActor
final class OnboardingViewModel: ObservableObject {
    @Published var data = OnboardingData()
    @Published var step: Step = .goal
    @Published var notificationsAuthorized = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    enum Step: Int, CaseIterable {
        case goal, experience, frequency, reminder, physique, done
    }

    var canContinue: Bool {
        switch step {
        case .goal, .experience, .frequency, .reminder, .physique: return true
        case .done: return true
        }
    }

    func next() {
        if step == .reminder, data.wantsNotifications {
            NotificationManager.shared.authStatus { [weak self] status in
                guard let self = self else { return }
                if status == .notDetermined {
                    NotificationManager.shared.requestAuthorization { ok in
                        Task { @MainActor in self.notificationsAuthorized = ok }
                    }
                } else {
                    Task { @MainActor in self.notificationsAuthorized = (status == .authorized) }
                }
            }
        }

        if step == .physique {
            complete()
        } else {
            step = Step(rawValue: step.rawValue + 1) ?? .done
        }
    }

    func back() {
        if step.rawValue > 0 {
            step = Step(rawValue: step.rawValue - 1) ?? .goal
        }
    }

    private func complete() {
        // Persist the user profile for now to UserDefaults; swap later for Core Data/CloudKit.
        let profile = UserProfile(
            createdAt: .now,
            goal: data.goal,
            experience: data.experience,
            daysPerWeek: data.daysPerWeek,
            reminderTime: data.wantsNotifications ? data.reminderTime : nil,
            gender: data.gender,
            age: data.age,
            heightInCm: data.heightInCm,
            weight: data.weight,
            units: data.units
        )
        if let encoded = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(encoded, forKey: "userProfile")
        }

        if data.wantsNotifications {
            NotificationManager.shared.scheduleWeeklyReminders(time: data.reminderTime, daysPerWeek: data.daysPerWeek)
        }

        hasCompletedOnboarding = true
        step = .done
    }
}
