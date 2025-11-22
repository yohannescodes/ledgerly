import CoreData
import Foundation
import SwiftUI
import Combine

@MainActor
final class WalletsStore: ObservableObject {
    @Published private(set) var wallets: [WalletModel] = []

    private let persistence: PersistenceController

    init(persistence: PersistenceController) {
        self.persistence = persistence
        reload()
    }

    func reload() {
        let context = persistence.container.viewContext
        do {
            let results = try context.fetch(Wallet.fetchRequestAll())
            wallets = results.map(WalletModel.init)
        } catch {
            assertionFailure("Failed to fetch wallets: \(error)")
            wallets = []
        }
    }

    func addWallet(input: WalletFormInput) {
        let nextSortOrder = Int16(wallets.count)
        let context = persistence.newBackgroundContext()
        context.perform {
            let wallet = Wallet.create(
                in: context,
                name: input.name,
                walletType: input.kind.storedValue,
                currencyCode: input.currencyCode,
                iconName: input.icon.rawValue,
                startingBalance: input.startingBalance,
                includeInNetWorth: input.includeInNetWorth
            )
            wallet.currentBalance = NSDecimalNumber(decimal: input.currentBalance)
            wallet.sortOrder = nextSortOrder
            wallet.updatedAt = Date()
            do {
                try context.save()
            } catch {
                assertionFailure("Failed to add wallet: \(error)")
            }
            Task { @MainActor in
                self.reload()
                NotificationCenter.default.post(name: .walletsDidChange, object: nil)
            }
        }
    }

    func updateWallet(walletID: NSManagedObjectID, input: WalletFormInput) {
        let context = persistence.newBackgroundContext()
        context.perform {
            guard let wallet = try? context.existingObject(with: walletID) as? Wallet else { return }
            wallet.name = input.name
            wallet.walletType = input.kind.storedValue
            wallet.baseCurrencyCode = input.currencyCode
            wallet.iconName = input.icon.rawValue
            wallet.startingBalance = NSDecimalNumber(decimal: input.startingBalance)
            wallet.currentBalance = NSDecimalNumber(decimal: input.currentBalance)
            wallet.includeInNetWorth = input.includeInNetWorth
            wallet.updatedAt = Date()
            do {
                try context.save()
            } catch {
                assertionFailure("Failed to update wallet: \(error)")
            }
            Task { @MainActor in
                self.reload()
                NotificationCenter.default.post(name: .walletsDidChange, object: nil)
            }
        }
    }

    func deleteWallet(walletID: NSManagedObjectID) {
        let context = persistence.newBackgroundContext()
        context.perform {
            guard let wallet = try? context.existingObject(with: walletID) else { return }
            context.delete(wallet)
            do {
                try context.save()
            } catch {
                assertionFailure("Failed to delete wallet: \(error)")
            }
            Task { @MainActor in
                self.reload()
                NotificationCenter.default.post(name: .walletsDidChange, object: nil)
            }
        }
    }
}
