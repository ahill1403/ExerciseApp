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
    @Published var recommendedPlan: WeeklyPlan?
    @Published var planDecision: PlanDecision?
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    enum Step: Int, CaseIterable {
        case goal, experience, frequency, reminder, physique, plan, done
    }

    enum PlanDecision { case recommended, custom }

    var canContinue: Bool {
        switch step {
        case .goal, .experience, .frequency, .reminder, .physique: return true
        case .plan: return planDecision != nil
        case .done: return true
        }
    }

    var visibleSteps: [Step] {
        var steps: [Step] = [.goal, .experience, .frequency, .reminder, .physique]
        if data.experience != .novice {
            steps.append(.plan)
        }
        return steps
    }

    var progress: (value: Double, total: Double) {
        if step == .done {
            let total = Double(visibleSteps.count + 1)
            return (total, total)
        }
        let steps = visibleSteps
        if let index = steps.firstIndex(of: step) {
            return (Double(index + 1), Double(steps.count))
        } else {
            let total = Double(steps.count)
            return (total, total)
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

        switch step {
        case .physique:
            if data.experience == .novice {
                complete(applyRecommended: true)
            } else {
                planDecision = nil
                recommendedPlan = PlannerStore.shared.recommendedPlan(for: buildProfile())
                step = .plan
            }
        case .plan:
            let apply = (planDecision == .recommended)
            complete(applyRecommended: apply)
        default:
            step = Step(rawValue: step.rawValue + 1) ?? .done
        }
    }

    func back() {
        if step == .plan {
            planDecision = nil
            step = .physique
        } else if step.rawValue > 0 {
            step = Step(rawValue: step.rawValue - 1) ?? .goal
        }
    }

    private func complete(applyRecommended: Bool) {
        let profile = buildProfile()
        if let encoded = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(encoded, forKey: "userProfile")
        }

        UserDefaults.standard.set(data.daysPerWeek, forKey: "weeklyGoal")

        if applyRecommended {
            let plan = PlannerStore.shared.recommendedPlan(for: profile)
            PlannerStore.shared.save(plan)
            recommendedPlan = plan
        } else {
            PlannerStore.shared.save(WeeklyPlan())
        }

        if data.wantsNotifications {
            NotificationManager.shared.scheduleWeeklyReminders(time: data.reminderTime, daysPerWeek: data.daysPerWeek)
        }

        hasCompletedOnboarding = true
        step = .done
    }

    private func buildProfile() -> UserProfile {
        // Persist the user profile for now to UserDefaults; swap later for Core Data/CloudKit.
        let experienceByArea = FitnessArea.defaultExperienceLevels.merging(data.experienceByArea) { _, new in new }

        return UserProfile(
            createdAt: .now,
            goal: data.goal,
            experience: data.experience,
            experienceByArea: experienceByArea,
            daysPerWeek: data.daysPerWeek,
            minutesPerDay: data.minutesPerDay,
            reminderTime: data.wantsNotifications ? data.reminderTime : nil,
            gender: data.gender,
            ageRange: data.ageRange,
            heightInCm: data.heightInCm,
            weight: data.weight,
            units: data.units
        )
    }
}
