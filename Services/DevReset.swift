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
    }
}
