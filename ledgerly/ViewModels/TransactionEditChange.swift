import CoreData
import Foundation

enum TransactionEditChange {
    case direction(TransactionFormInput.Direction)
    case amount(Decimal)
    case currency(String)
    case wallet(NSManagedObjectID)
    case date(Date)
    case notes(String)
    case category(NSManagedObjectID?)
}
