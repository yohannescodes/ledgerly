import CoreData
import Foundation

struct TransactionModel: Identifiable, Hashable {
    struct DisplayCategory: Hashable {
        let name: String
        let colorHex: String?
        let iconName: String?
    }

    let id: NSManagedObjectID
    let identifier: String
    let direction: String
    let amount: Decimal
    let currencyCode: String
    let convertedAmountBase: Decimal
    let date: Date
    let notes: String?
    let walletName: String
    let walletCurrency: String
    let walletID: NSManagedObjectID?
    let category: DisplayCategory?
    let categoryID: NSManagedObjectID?

    var signedAmount: Decimal {
        switch direction.lowercased() {
        case "expense": return -amount
        case "transfer": return .zero
        default: return amount
        }
    }

    var signedBaseAmount: Decimal {
        switch direction.lowercased() {
        case "expense": return -convertedAmountBase
        case "transfer": return .zero
        default: return convertedAmountBase
        }
    }
}

extension TransactionModel {
    init(managedObject: Transaction) {
        id = managedObject.objectID
        identifier = managedObject.identifier ?? UUID().uuidString
        direction = managedObject.direction ?? "expense"
        amount = managedObject.amount as Decimal? ?? .zero
        currencyCode = managedObject.currencyCode ?? "USD"
        convertedAmountBase = managedObject.convertedAmountBase as Decimal? ?? .zero
        date = managedObject.date ?? Date()
        notes = managedObject.notes
        walletName = managedObject.wallet?.name ?? "Wallet"
        walletCurrency = managedObject.wallet?.baseCurrencyCode ?? currencyCode
        walletID = managedObject.wallet?.objectID
        if let cat = managedObject.category {
            category = DisplayCategory(name: cat.name ?? "Category", colorHex: cat.colorHex, iconName: cat.iconName)
        } else {
            category = nil
        }
        categoryID = managedObject.category?.objectID
    }
}

extension Transaction {
    static func fetchRequestAll(limit: Int? = nil) -> NSFetchRequest<Transaction> {
        let request: NSFetchRequest<Transaction> = Transaction.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Transaction.date, ascending: false)]
        if let limit { request.fetchLimit = limit }
        return request
    }

    static func create(
        in context: NSManagedObjectContext,
        identifier: String = UUID().uuidString,
        direction: String,
        amount: Decimal,
        currencyCode: String,
        convertedAmountBase: Decimal,
        date: Date,
        wallet: Wallet,
        category: Category?
    ) -> Transaction {
        let transaction = Transaction(context: context)
        transaction.identifier = identifier
        transaction.direction = direction
        transaction.amount = NSDecimalNumber(decimal: amount)
        transaction.currencyCode = currencyCode
        transaction.convertedAmountBase = NSDecimalNumber(decimal: convertedAmountBase)
        transaction.date = date
        transaction.wallet = wallet
        transaction.category = category
        transaction.isTransfer = (direction == "transfer")
        transaction.createdAt = Date()
        transaction.updatedAt = Date()
        return transaction
    }
}
