import Foundation
import CoreData
import UserNotifications

struct GoalReminderPayload {
    let goalName: String
    let deadline: Date
}

final class GoalReminderService {
    func scheduleReminder(payload: GoalReminderPayload) {
        guard payload.deadline > Date() else { return }
        let context = PersistenceController.shared.container.viewContext
        guard AppSettings.fetchSingleton(in: context)?.notificationsEnabled ?? true else { return }
        let content = UNMutableNotificationContent()
        content.title = "Goal Reminder"
        content.body = "\(payload.goalName) is due soon."
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(payload.deadline.timeIntervalSinceNow, 60), repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
}
