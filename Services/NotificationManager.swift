//
//  NotificationManager.swift
//  AtlasFit
//
//  Created by Aaron Hill on 9/11/25.
//

import Foundation
import UserNotifications

enum NotificationAuthStatus { case notDetermined, authorized, denied }

final class NotificationManager {
    static let shared = NotificationManager()
    
    func cancelReminders() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["atlasfit.dailyReminder"])
    }

    func authStatus(completion: @escaping (NotificationAuthStatus) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .notDetermined: completion(.notDetermined)
            case .denied: completion(.denied)
            default: completion(.authorized)
            }
        }
    }

    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { ok, _ in
            completion(ok)
        }
    }

    func scheduleWeeklyReminders(time: Date, daysPerWeek: Int) {
        // Simple approach: schedule a daily reminder; you can later map to specific days based on the user’s plan.
        let content = UNMutableNotificationContent()
        content.title = "Time to train"
        content.body = "Small steps today → big changes tomorrow."
        content.sound = .default

        var date = Calendar.current.dateComponents([.hour, .minute], from: time)
        date.second = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: true)
        let req = UNNotificationRequest(identifier: "atlasfit.dailyReminder", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(req)

        // If you want exactly N reminders/week, you can later schedule on specific weekdays from planner data.
    }
}
