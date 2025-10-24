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
    @Published var step: Step = .experience
    @Published var notificationsAuthorized = false
    @Published var recommendedPlan: WeeklyPlan?
    @Published var planDecision: PlanDecision?
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    enum Step: Int, CaseIterable {
        case experience, goal, frequency, reminder, physique, plan, done
    }

    enum PlanDecision { case recommended, custom }

    // MARK: - Path control (prevents progress bar from jumping on selection)
    private let fullPath: [Step] = [.experience, .goal, .frequency, .reminder, .physique, .plan, .done]
    private let beginnerPath: [Step] = [.experience, .frequency, .reminder, .done]

    // We start with the full path. This will be swapped on Continue from .experience if Beginner is chosen.
    private var path: [Step] = [.experience, .goal, .frequency, .reminder, .physique, .plan, .done]

    // MARK: - Gating and progress
    var canContinue: Bool {
        switch step {
        case .goal, .experience, .frequency, .reminder, .physique: return true
        case .plan: return planDecision != nil
        case .done: return true
        }
    }

    /// Visible steps exclude `.done` so the bar fills to 100% on the final screen.
    var visibleSteps: [Step] {
        path.filter { $0 != .done }
    }

    var progress: (value: Double, total: Double) {
        // When on .done, show a completely full bar regardless of path length.
        if step == .done {
            let total = Double(visibleSteps.count + 1)
            return (total, total)
        }

        let steps = visibleSteps
        if let index = steps.firstIndex(of: step) {
            return (Double(index + 1), Double(steps.count))
        } else {
            // Fallback: if step isn't in visibleSteps (shouldn't happen), show full.
            let total = Double(steps.count)
            return (total, total)
        }
    }

    // MARK: - Navigation
    func next() {
        // Handle notification authorization request timing
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
        case .experience:
            // Freeze the path only AFTER the user taps Continue on Experience.
            if data.experience == .beginner {
                // Beginner short path: Frequency → Reminder → Done
                path = beginnerPath
                // We’ll apply a recommended plan automatically at completion.
                planDecision = .recommended
                recommendedPlan = nil
            } else {
                // Full path for non-beginner
                path = fullPath
                planDecision = nil
                recommendedPlan = nil
            }
            goToNextInPath()

        case .physique:
            // Prepare a recommended plan before Plan step on the full path
            recommendedPlan = PlannerStore.shared.recommendedPlan(for: buildProfile())
            planDecision = nil
            goToNextInPath()

        case .plan:
            // Finalize with either recommended or custom plan
            let apply = (planDecision ?? .recommended) == .recommended
            complete(applyRecommended: apply)

        default:
            goToNextInPath()
        }
    }

    func back() {
        goToPreviousInPath()
    }

    func skip() {
        switch step {
        case .goal, .frequency, .physique:
            next()
        case .reminder:
            data.wantsNotifications = false
            next()
        case .plan:
            planDecision = .recommended
            next()
        default:
            break
        }
    }

    // MARK: - Path helpers
    private func goToNextInPath() {
        guard let idx = path.firstIndex(of: step) else { return }
        let nextIdx = idx + 1
        if nextIdx < path.count {
            step = path[nextIdx]
        } else {
            step = .done
        }
    }

    private func goToPreviousInPath() {
        guard let idx = path.firstIndex(of: step) else { return }
        let prevIdx = idx - 1
        if prevIdx >= 0 {
            step = path[prevIdx]
        } else {
            step = .experience
        }
    }

    // MARK: - Completion
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

    // MARK: - Profile building
    private func buildProfile() -> UserProfile {
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
