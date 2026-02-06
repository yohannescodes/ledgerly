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
            let existingStarting = wallet.startingBalance as Decimal? ?? .zero
            let existingCurrent = wallet.currentBalance as Decimal? ?? .zero
            let existingCurrency = (wallet.baseCurrencyCode ?? input.currencyCode).uppercased()
            let desiredCurrency = input.currencyCode.uppercased()
            let shouldAdjustBalance = existingStarting != input.startingBalance
                || existingCurrent != input.currentBalance
                || existingCurrency != desiredCurrency
            let converter = CurrencyConverter.fromSettings(in: context)
            let now = Date()
            let ledgerBalance = shouldAdjustBalance
                ? Self.ledgerBalance(
                    for: wallet,
                    startingBalance: input.startingBalance,
                    walletCurrency: desiredCurrency,
                    asOf: now,
                    converter: converter,
                    in: context
                )
                : input.currentBalance
            wallet.name = input.name
            wallet.walletType = input.kind.storedValue
            wallet.baseCurrencyCode = input.currencyCode
            wallet.iconName = input.icon.rawValue
            wallet.startingBalance = NSDecimalNumber(decimal: input.startingBalance)
            wallet.currentBalance = NSDecimalNumber(decimal: input.currentBalance)
            wallet.includeInNetWorth = input.includeInNetWorth
            wallet.updatedAt = Date()
            if shouldAdjustBalance {
                let delta = input.currentBalance - ledgerBalance
                let threshold = Decimal(string: "0.0001") ?? .zero
                let deltaAbs = delta < .zero ? -delta : delta
                if deltaAbs > threshold {
                    let direction = delta >= 0 ? "income" : "expense"
                    let amount = deltaAbs
                    let convertedAmountBase = converter.convertToBase(amount, currency: desiredCurrency)
                    _ = Transaction.create(
                        in: context,
                        direction: direction,
                        amount: amount,
                        currencyCode: desiredCurrency,
                        convertedAmountBase: convertedAmountBase,
                        date: now,
                        wallet: wallet,
                        category: nil,
                        notes: "Balance adjustment",
                        affectsBalance: false
                    )
                }
            }
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

    private static func ledgerBalance(
        for wallet: Wallet,
        startingBalance: Decimal,
        walletCurrency: String,
        asOf date: Date,
        converter: CurrencyConverter,
        in context: NSManagedObjectContext
    ) -> Decimal {
        var balance = startingBalance
        let request: NSFetchRequest<Transaction> = Transaction.fetchRequest()
        let datePredicate = NSPredicate(format: "date <= %@", date as NSDate)
        let walletPredicate = NSPredicate(format: "wallet == %@", wallet)
        let counterpartyPredicate = NSPredicate(format: "counterpartyWallet == %@", wallet)
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            datePredicate,
            NSCompoundPredicate(orPredicateWithSubpredicates: [walletPredicate, counterpartyPredicate])
        ])
        guard let transactions = try? context.fetch(request) else { return balance }
        for transaction in transactions {
            if transaction.affectsBalance == false { continue }
            let amount = transaction.amount as Decimal? ?? .zero
            let baseAmount = converter.convertToBase(amount, currency: transaction.currencyCode)
            let walletAmount = converter.convertFromBase(baseAmount, to: walletCurrency)
            let direction = (transaction.direction ?? "expense").lowercased()
            if transaction.wallet == wallet {
                switch direction {
                case "income":
                    balance += walletAmount
                case "expense", "transfer":
                    balance -= walletAmount
                default:
                    balance += walletAmount
                }
            }
            if direction == "transfer", transaction.counterpartyWallet == wallet {
                balance += walletAmount
            }
        }
        return balance
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
