//
//  DevReset.swift
//  AtlasFit
//
//  Created by Aaron Hill on 9/11/25.
//

import Foundation

enum DevReset {
    static func resetOnboarding() {
        let ud = UserDefaults.standard
        ud.set(false, forKey: "hasCompletedOnboarding")
        ud.removeObject(forKey: "userProfile")
        NotificationManager.shared.cancelReminders()
    }
}
 // Test
