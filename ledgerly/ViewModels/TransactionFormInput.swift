import Foundation
import CoreData

struct TransactionFormInput {
    enum Direction: String, CaseIterable, Identifiable {
        case expense
        case income
        case transfer

        var id: String { rawValue }

        var title: String {
            switch self {
            case .expense: return "Expense"
            case .income: return "Income"
            case .transfer: return "Transfer"
            }
        }
    }

    var direction: Direction = .expense
    var amount: Decimal = .zero
    var currencyCode: String = Locale.current.currency?.identifier ?? "USD"
    var walletID: NSManagedObjectID?
    var destinationWalletID: NSManagedObjectID?
    var categoryID: NSManagedObjectID?
    var date: Date = Date()
    var notes: String = ""
}
