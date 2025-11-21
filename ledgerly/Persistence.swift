//
//  Persistence.swift
//  ledgerly
//
//  Created by Yohannes Haile on 11/21/25.
//

import CoreData

final class PersistenceController {
    static let shared = PersistenceController()

    @MainActor
    static let preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext
        context.performAndWait {
            if AppSettings.fetchSingleton(in: context) == nil {
                let settings = AppSettings.makeDefault(in: context)
                settings.hasCompletedOnboarding = true
            }
            controller.seedDemoIfNeeded(in: context)
        }

        do {
            try context.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }

        return controller
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "ledgerly")
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }

        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }

        configureContexts()
        seedDefaultsIfNeeded()
    }

    func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        context.automaticallyMergesChangesFromParent = true
        return context
    }

    private func configureContexts() {
        let context = container.viewContext
        context.automaticallyMergesChangesFromParent = true
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        context.shouldDeleteInaccessibleFaults = true
        context.undoManager = nil
    }

    private func seedDefaultsIfNeeded() {
        let context = container.viewContext
        context.perform { [weak context, weak self] in
            guard let context else { return }
            if AppSettings.fetchSingleton(in: context) == nil {
                _ = AppSettings.makeDefault(in: context)
            }
            self?.seedDemoIfNeeded(in: context)
            do {
                try context.save()
            } catch {
                let nsError = error as NSError
                fatalError("Failed to seed defaults: \(nsError), \(nsError.userInfo)")
            }
        }
    }

    private func seedDemoIfNeeded(in context: NSManagedObjectContext) {
        let walletRequest: NSFetchRequest<Wallet> = Wallet.fetchRequest()
        walletRequest.fetchLimit = 1
        let walletCount = (try? context.count(for: walletRequest)) ?? 0
        guard walletCount == 0 else {
            seedNetWorthSnapshotIfNeeded(in: context)
            return
        }

        let salaryWallet = Wallet.create(
            in: context,
            name: "Salary Account",
            walletType: "bank",
            currencyCode: Locale.current.currency?.identifier ?? "USD",
            iconName: "building.columns",
            startingBalance: 5_000
        )

        let cashWallet = Wallet.create(
            in: context,
            name: "Cash",
            walletType: "cash",
            currencyCode: Locale.current.currency?.identifier ?? "USD",
            iconName: "banknote",
            startingBalance: 400
        )

        let groceries = Category.create(in: context, name: "Groceries", type: "expense", colorHex: "#FF9F0A", iconName: "cart")
        let transport = Category.create(in: context, name: "Transport", type: "expense", colorHex: "#0A84FF", iconName: "car")
        let freelance = Category.create(in: context, name: "Freelance", type: "income", colorHex: "#32D74B", iconName: "laptopcomputer")

        _ = Transaction.create(
            in: context,
            direction: "expense",
            amount: Decimal(120.45),
            currencyCode: salaryWallet.baseCurrencyCode ?? "USD",
            convertedAmountBase: Decimal(120.45),
            date: Date().addingTimeInterval(-3600 * 12),
            wallet: salaryWallet,
            category: groceries
        )

        _ = Transaction.create(
            in: context,
            direction: "expense",
            amount: Decimal(35.10),
            currencyCode: cashWallet.baseCurrencyCode ?? "USD",
            convertedAmountBase: Decimal(35.10),
            date: Date().addingTimeInterval(-3600 * 36),
            wallet: cashWallet,
            category: transport
        )

        _ = Transaction.create(
            in: context,
            direction: "income",
            amount: Decimal(850),
            currencyCode: salaryWallet.baseCurrencyCode ?? "USD",
            convertedAmountBase: Decimal(850),
            date: Date().addingTimeInterval(-3600 * 72),
            wallet: salaryWallet,
            category: freelance
        )

        let brokerage = InvestmentAccount.create(
            in: context,
            name: "Brokerage",
            institution: "Ledgerly Demo",
            accountType: "brokerage",
            currencyCode: salaryWallet.baseCurrencyCode ?? "USD"
        )

        let appleAsset = InvestmentAsset.create(
            in: context,
            symbol: "AAPL",
            assetType: "stock",
            name: "Apple Inc.",
            exchange: "NASDAQ",
            currencyCode: salaryWallet.baseCurrencyCode ?? "USD"
        )

        _ = HoldingLot.create(
            in: context,
            quantity: Decimal(5),
            costPerUnit: Decimal(150),
            acquiredDate: Date().addingTimeInterval(-86400 * 30),
            account: brokerage,
            asset: appleAsset
        )

        _ = PriceSnapshot.record(
            in: context,
            asset: appleAsset,
            price: Decimal(180),
            currencyCode: appleAsset.currencyCode ?? "USD",
            provider: "demo"
        )

        _ = ManualAsset.create(
            in: context,
            name: "Car",
            type: "tangible",
            value: 12000,
            currencyCode: salaryWallet.baseCurrencyCode ?? "USD",
            includeInCore: true,
            includeInTangible: true,
            volatility: false
        )

        _ = ManualLiability.create(
            in: context,
            name: "Student Loan",
            type: "loan",
            balance: 8000,
            currencyCode: salaryWallet.baseCurrencyCode ?? "USD"
        )

        seedNetWorthSnapshotIfNeeded(in: context)
    }

    private func seedNetWorthSnapshotIfNeeded(in context: NSManagedObjectContext) {
        let snapshotRequest: NSFetchRequest<NetWorthSnapshot> = NetWorthSnapshot.fetchRequest()
        snapshotRequest.fetchLimit = 1
        let count = (try? context.count(for: snapshotRequest)) ?? 0
        guard count == 0 else { return }
        let service = NetWorthService(persistence: self)
        let totals = service.computeTotals()
        _ = NetWorthSnapshot.create(
            in: context,
            totalAssets: totals.totalAssets,
            totalLiabilities: totals.totalLiabilities,
            coreNetWorth: totals.coreNetWorth,
            tangibleNetWorth: totals.tangibleNetWorth,
            volatileAssets: totals.volatileAssets
        )
    }
}
