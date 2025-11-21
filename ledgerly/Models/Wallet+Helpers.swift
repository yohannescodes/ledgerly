import CoreData
import Foundation

struct WalletModel: Identifiable, Hashable {
    let id: NSManagedObjectID
    let identifier: String
    let name: String
    let iconName: String?
    let currencyCode: String
    let walletType: String
    let currentBalance: Decimal
    let startingBalance: Decimal
    let includeInNetWorth: Bool
    let archived: Bool
}

extension WalletModel {
    init(managedObject: Wallet) {
        id = managedObject.objectID
        identifier = managedObject.identifier ?? UUID().uuidString
        name = managedObject.name ?? "Wallet"
        iconName = managedObject.iconName
        currencyCode = managedObject.baseCurrencyCode ?? "USD"
        walletType = managedObject.walletType ?? "custom"
        currentBalance = managedObject.currentBalance as Decimal? ?? .zero
        startingBalance = managedObject.startingBalance as Decimal? ?? .zero
        includeInNetWorth = managedObject.includeInNetWorth
        archived = managedObject.archived
    }
}

extension Wallet {
    static func fetchRequestAll() -> NSFetchRequest<Wallet> {
        let request: NSFetchRequest<Wallet> = Wallet.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Wallet.sortOrder, ascending: true)]
        return request
    }

    static func create(
        in context: NSManagedObjectContext,
        identifier: String = UUID().uuidString,
        name: String,
        walletType: String,
        currencyCode: String,
        iconName: String? = nil,
        startingBalance: Decimal,
        includeInNetWorth: Bool = true
    ) -> Wallet {
        let wallet = Wallet(context: context)
        wallet.identifier = identifier
        wallet.name = name
        wallet.walletType = walletType
        wallet.baseCurrencyCode = currencyCode
        wallet.iconName = iconName
        wallet.startingBalance = NSDecimalNumber(decimal: startingBalance)
        wallet.currentBalance = NSDecimalNumber(decimal: startingBalance)
        wallet.includeInNetWorth = includeInNetWorth
        wallet.archived = false
        wallet.sortOrder = 0
        wallet.createdAt = Date()
        wallet.updatedAt = Date()
        return wallet
    }
}
