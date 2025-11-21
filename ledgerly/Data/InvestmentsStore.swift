import CoreData
import Foundation
import SwiftUI
import Combine

@MainActor
final class InvestmentsStore: ObservableObject {
    @Published private(set) var accounts: [InvestmentAccountModel] = []

    private let persistence: PersistenceController
    private let priceService: PriceService

    init(persistence: PersistenceController) {
        self.persistence = persistence
        self.priceService = PriceService(persistence: persistence)
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

    func addHolding(
        accountID: NSManagedObjectID,
        symbol: String,
        assetName: String,
        assetType: String,
        quantity: Decimal,
        costPerUnit: Decimal,
        acquiredDate: Date
    ) {
        let context = persistence.newBackgroundContext()
        context.perform {
            guard let account = try? context.existingObject(with: accountID) as? InvestmentAccount else { return }
            let asset = self.fetchOrCreateAsset(
                symbol: symbol,
                name: assetName,
                assetType: assetType,
                currency: account.currencyCode ?? "USD",
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

            try? context.save()

            Task { @MainActor in
                self.reload()
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
