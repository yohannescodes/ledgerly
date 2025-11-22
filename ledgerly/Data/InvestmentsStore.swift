import CoreData
import Foundation
import SwiftUI
import Combine

@MainActor
final class InvestmentsStore: ObservableObject {
    @Published private(set) var accounts: [InvestmentAccountModel] = []

    private let persistence: PersistenceController
    private let priceService: PriceService

    init(persistence: PersistenceController, priceService: PriceService? = nil) {
        self.persistence = persistence
        self.priceService = priceService ?? PriceService(persistence: persistence)
        reload()
    }

    func reload() {
        let context = persistence.container.viewContext
        let request: NSFetchRequest<InvestmentAccount> = InvestmentAccount.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \InvestmentAccount.name, ascending: true)]
        do {
            let accounts = try context.fetch(request)
            self.accounts = accounts.map(InvestmentAccountModel.init)
        } catch {
            assertionFailure("Failed to fetch investment accounts: \(error)")
            accounts = []
        }
    }

    func refreshPrices() {
        priceService.refreshPricesIfNeeded()
        reload()
    }

    func addAccount(name: String, institution: String?, type: String, currencyCode: String) {
        let context = persistence.newBackgroundContext()
        context.perform {
            _ = InvestmentAccount.create(
                in: context,
                name: name,
                institution: institution,
                accountType: type,
                currencyCode: currencyCode
            )
            try? context.save()
            Task { @MainActor in self.reload() }
        }
    }

    func deleteAccount(accountID: NSManagedObjectID) {
        let context = persistence.newBackgroundContext()
        context.perform {
            guard let account = try? context.existingObject(with: accountID) else { return }
            context.delete(account)
            try? context.save()
            Task { @MainActor in
                self.reload()
                NotificationCenter.default.post(name: .investmentsDidChange, object: nil)
            }
        }
    }

    func addHolding(
        accountID: NSManagedObjectID,
        symbol: String,
        assetName: String,
        assetType: String,
        quantity: Decimal,
        costPerUnit: Decimal,
        acquiredDate: Date,
        currencyCode: String,
        fundingWalletID: NSManagedObjectID? = nil
    ) {
        let context = persistence.newBackgroundContext()
        context.perform {
            guard let account = try? context.existingObject(with: accountID) as? InvestmentAccount else { return }
            let asset = self.fetchOrCreateAsset(
                symbol: symbol,
                name: assetName,
                assetType: assetType,
                currency: currencyCode,
                in: context
            )

            _ = HoldingLot.create(
                in: context,
                quantity: quantity,
                costPerUnit: costPerUnit,
                acquiredDate: acquiredDate,
                account: account,
                asset: asset
            )

            if let walletID = fundingWalletID,
               let wallet = try? context.existingObject(with: walletID) as? Wallet {
                let totalCost = quantity * costPerUnit
                let updated = (wallet.currentBalance as Decimal? ?? .zero) - totalCost
                wallet.currentBalance = NSDecimalNumber(decimal: updated)
                wallet.updatedAt = Date()
                Transaction.create(
                    in: context,
                    direction: "expense",
                    amount: totalCost,
                    currencyCode: wallet.baseCurrencyCode ?? "USD",
                    convertedAmountBase: totalCost,
                    date: Date(),
                    wallet: wallet,
                    category: nil
                )
            }

            try? context.save()

            Task { @MainActor in
                self.priceService.refreshPrices(for: [symbol])
                self.reload()
                NotificationCenter.default.post(name: .investmentsDidChange, object: nil)
            }
        }
    }

    func sellHolding(
        lotID: NSManagedObjectID,
        quantity: Decimal,
        salePrice: Decimal,
        destinationWalletID: NSManagedObjectID?
    ) {
        let context = persistence.newBackgroundContext()
        context.perform {
            guard let lot = try? context.existingObject(with: lotID) as? HoldingLot else { return }
            let available = lot.quantity as Decimal? ?? .zero
            guard quantity > 0, quantity <= available else { return }
            let remainingQuantity = available - quantity
            if remainingQuantity <= 0 {
                context.delete(lot)
            } else {
                lot.quantity = NSDecimalNumber(decimal: remainingQuantity)
            }

            if let walletID = destinationWalletID,
               let wallet = try? context.existingObject(with: walletID) as? Wallet {
                let proceeds = quantity * salePrice
                wallet.currentBalance = NSDecimalNumber(decimal: (wallet.currentBalance as Decimal? ?? .zero) + proceeds)
                wallet.updatedAt = Date()
                Transaction.create(
                    in: context,
                    direction: "income",
                    amount: proceeds,
                    currencyCode: wallet.baseCurrencyCode ?? "USD",
                    convertedAmountBase: proceeds,
                    date: Date(),
                    wallet: wallet,
                    category: nil
                )
                _ = HoldingSale.record(
                    in: context,
                    lot: lot,
                    quantity: quantity,
                    price: salePrice,
                    walletName: wallet.name
                )
            } else {
                _ = HoldingSale.record(
                    in: context,
                    lot: lot,
                    quantity: quantity,
                    price: salePrice,
                    walletName: nil
                )
            }

            try? context.save()

            Task { @MainActor in
                self.reload()
                NotificationCenter.default.post(name: .investmentsDidChange, object: nil)
            }
        }
    }

    func deleteHolding(lotID: NSManagedObjectID) {
        let context = persistence.newBackgroundContext()
        context.perform {
            guard let lot = try? context.existingObject(with: lotID) else { return }
            context.delete(lot)
            try? context.save()
            Task { @MainActor in
                self.reload()
                NotificationCenter.default.post(name: .investmentsDidChange, object: nil)
            }
        }
    }

    private func fetchOrCreateAsset(
        symbol: String,
        name: String,
        assetType: String,
        currency: String,
        in context: NSManagedObjectContext
    ) -> InvestmentAsset {
        let request: NSFetchRequest<InvestmentAsset> = InvestmentAsset.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "symbol ==[c] %@", symbol)
        if let existing = try? context.fetch(request).first {
            return existing
        }
        return InvestmentAsset.create(
            in: context,
            symbol: symbol.uppercased(),
            assetType: assetType,
            name: name,
            exchange: nil,
            currencyCode: currency
        )
    }
}
