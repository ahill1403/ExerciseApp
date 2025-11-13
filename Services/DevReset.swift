//
//  DevReset.swift
//  REPS
//
//  Created by Aaron Hill on 9/11/25.
//

import Foundation

enum DevReset {
    static func resetOnboarding() {
        let ud = UserDefaults.standard
        ud.set(false, forKey: "hasCompletedOnboarding")
        ud.removeObject(forKey: "userProfile")
        ud.removeObject(forKey: "workoutHistory")
        ud.removeObject(forKey: "weeklyPlan")
        NotificationManager.shared.cancelReminders()
        ud.synchronize()
    }

    /// Clears all persisted state and returns the app to first-run.
    static func fullReset() {
        let ud = UserDefaults.standard

        // Core onboarding gate
        ud.set(false, forKey: "hasCompletedOnboarding")

        // App data
        ud.removeObject(forKey: "userProfile")
        ud.removeObject(forKey: "weeklyPlan")
        ud.removeObject(forKey: "workoutHistory")

        // App preferences / flags
        ud.removeObject(forKey: "weeklyGoal")
        ud.removeObject(forKey: "appleHealthEnabled")

        // Notifications
        NotificationManager.shared.cancelReminders()

        ud.synchronize()
    }
}

