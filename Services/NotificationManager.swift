import Foundation
import UserNotifications

enum NotificationAuthStatus { case notDetermined, authorized, denied }

final class NotificationManager {
    static let shared = NotificationManager()
    
    func cancelReminders() {
        let daily = ["atlasfit.dailyReminder"]
        let weekly = (1...7).map { "atlasfit.reminder.\($0)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: daily + weekly)
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
    
    /// Schedule explicit weekday reminders (1=Sun … 7=Sat) at a given time.
    func scheduleReminders(time: Date, weekdays: [Int]) {
        let center = UNUserNotificationCenter.current()
        // Clear old identifiers for a tidy slate
        cancelReminders()
        
        let comps = Calendar.current.dateComponents([.hour, .minute], from: time)
        
        for wd in weekdays.sorted() {
            var dc = DateComponents()
            dc.weekday = wd
            dc.hour = comps.hour
            dc.minute = comps.minute
            
            let content = UNMutableNotificationContent()
            content.title = "Time to train"
            content.body = "Small steps today → big changes tomorrow."
            content.sound = .default
            
            let trigger = UNCalendarNotificationTrigger(dateMatching: dc, repeats: true)
            let id = "atlasfit.reminder.\(wd)"
            let req = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
            center.add(req)
        }
    }
    
    /// Legacy daily fallback. Prefer `scheduleReminders(time:weekdays:)`.
    func scheduleWeeklyReminders(time: Date, daysPerWeek: Int) {
        // For compatibility with existing callers; schedule daily until planner exists.
        let content = UNMutableNotificationContent()
        content.title = "Time to train"
        content.body = "Small steps today → big changes tomorrow."
        content.sound = .default
        var date = Calendar.current.dateComponents([.hour, .minute], from: time)
        date.second = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: true)
        let req = UNNotificationRequest(identifier: "atlasfit.dailyReminder", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(req)
    }
    
    /// Reads planned days from `PlannerStore`, or evenly spaces by weekly goal if none.
    func scheduleFromPlan(time: Date, fallbackGoal: Int) {
        let plan = PlannerStore.shared.load()
        let days = PlannerStore.shared.selectedWeekdays(from: plan)
        if days.isEmpty {
            let spaced = PlannerStore.shared.evenlySpacedWeekdays(goal: max(fallbackGoal, 1))
            scheduleReminders(time: time, weekdays: spaced)
        } else {
            scheduleReminders(time: time, weekdays: days)
        }
    }
}
