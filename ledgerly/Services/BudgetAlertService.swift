import CoreData
import Foundation
import UserNotifications

struct BudgetAlertPayload {
    let categoryName: String
    let threshold: Int
    let spentAmount: Decimal
    let budgetID: NSManagedObjectID?
}

final class BudgetAlertService {
    func scheduleAlert(payload: BudgetAlertPayload) {
        let content = UNMutableNotificationContent()
        content.title = "Budget Alert"
        content.body = "\(payload.categoryName) budget hit \(payload.threshold)%"
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
