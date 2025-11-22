import CoreData
import Foundation

enum DataBackupError: Error {
    case buildFailure
    case decodeFailure
}

struct LedgerlyBackup: Codable {
    struct Metadata: Codable {
        let version: Int
        let exportedAt: Date
    }

    struct CategoryRecord: Codable {
        let identifier: String
        let name: String
        let type: String
        let colorHex: String?
        let iconName: String?
        let sortOrder: Int16
    }

    struct WalletRecord: Codable {
        let identifier: String
        let name: String
        let walletType: String
        let baseCurrencyCode: String
        let iconName: String?
        let startingBalance: Decimal
        let currentBalance: Decimal
        let includeInNetWorth: Bool
        let archived: Bool
        let sortOrder: Int16
        let createdAt: Date?
        let updatedAt: Date?
    }

    struct TransactionRecord: Codable {
        let identifier: String
        let direction: String
        let amount: Decimal
        let currencyCode: String
        let convertedAmountBase: Decimal
        let date: Date
        let notes: String?
        let walletIdentifier: String?
        let categoryIdentifier: String?
        let isTransfer: Bool
        let counterpartyWalletIdentifier: String?
    }

    struct ManualAssetRecord: Codable {
        let identifier: String
        let name: String
        let type: String
        let value: Decimal
        let currencyCode: String
        let valuationDate: Date?
        let includeInCore: Bool
        let includeInTangible: Bool
        let volatility: Bool
    }

    struct ManualLiabilityRecord: Codable {
        let identifier: String
        let name: String
        let type: String
        let balance: Decimal
        let currencyCode: String
        let dueDate: Date?
    }

    struct BudgetRecord: Codable {
        let identifier: String
        let categoryIdentifier: String?
        let month: Int16
        let year: Int16
        let limitAmount: Decimal
        let currencyCode: String
        let autoReset: Bool
        let carryOverAmount: Decimal?
        let alert50Sent: Bool
        let alert80Sent: Bool
        let alert100Sent: Bool
    }

    struct GoalRecord: Codable {
        let identifier: String
        let name: String
        let targetAmount: Decimal
        let currencyCode: String
        let currentAmount: Decimal
        let deadline: Date?
        let status: String
        let walletIdentifier: String?
        let categoryIdentifier: String?
    }

    struct NetWorthSnapshotRecord: Codable {
        let identifier: String
        let timestamp: Date
        let totalAssets: Decimal
        let totalLiabilities: Decimal
        let coreNetWorth: Decimal
        let tangibleNetWorth: Decimal
        let volatileAssets: Decimal
        let notes: String?
    }

    struct InvestmentAccountRecord: Codable {
        let identifier: String
        let name: String
        let institution: String?
        let accountType: String
        let currencyCode: String
        let includeInNetWorth: Bool
        let createdAt: Date?
        let updatedAt: Date?
    }

    struct InvestmentAssetRecord: Codable {
        let identifier: String
        let symbol: String
        let assetType: String
        let name: String
        let exchange: String?
        let currencyCode: String
    }

    struct HoldingLotRecord: Codable {
        let identifier: String
        let quantity: Decimal
        let costPerUnit: Decimal
        let acquiredDate: Date
        let notes: String?
        let fee: Decimal?
        let accountIdentifier: String?
        let assetIdentifier: String?
    }

    struct PriceSnapshotRecord: Codable {
        let identifier: String
        let assetIdentifier: String?
        let price: Decimal
        let currencyCode: String
        let provider: String
        let timestamp: Date
        let isStale: Bool
    }

    struct HoldingSaleRecord: Codable {
        let identifier: String
        let lotIdentifier: String?
        let date: Date
        let quantity: Decimal
        let price: Decimal
        let walletName: String?
    }

    let metadata: Metadata
    let categories: [CategoryRecord]
    let wallets: [WalletRecord]
    let transactions: [TransactionRecord]
    let manualAssets: [ManualAssetRecord]
    let manualLiabilities: [ManualLiabilityRecord]
    let budgets: [BudgetRecord]
    let goals: [GoalRecord]
    let netWorthSnapshots: [NetWorthSnapshotRecord]
    let investmentAccounts: [InvestmentAccountRecord]
    let investmentAssets: [InvestmentAssetRecord]
    let holdingLots: [HoldingLotRecord]
    let priceSnapshots: [PriceSnapshotRecord]
    let holdingSales: [HoldingSaleRecord]
}

final class DataBackupService {
    private let persistence: PersistenceController
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(persistence: PersistenceController) {
        self.persistence = persistence
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func exportBackup() throws -> URL {
        var backup: LedgerlyBackup?
        var fetchError: Error?
        let context = persistence.container.viewContext
        context.performAndWait {
            do {
                backup = try self.buildBackup(in: context)
            } catch {
                fetchError = error
            }
        }
        if let fetchError { throw fetchError }
        guard let backup else { throw DataBackupError.buildFailure }
        let data = try encoder.encode(backup)
        let timestamp = Int(Date().timeIntervalSince1970)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("ledgerly_backup_\(timestamp).json")
        try data.write(to: url, options: .atomic)
        return url
    }

    func importBackup(from url: URL) throws {
        let data = try Data(contentsOf: url)
        let backup: LedgerlyBackup
        do {
            backup = try decoder.decode(LedgerlyBackup.self, from: data)
        } catch {
            throw DataBackupError.decodeFailure
        }

        let context = persistence.newBackgroundContext()
        var importError: Error?
        context.performAndWait {
            do {
                try self.apply(backup: backup, in: context)
                if context.hasChanges {
                    try context.save()
                }
            } catch {
                importError = error
            }
        }
        if let importError { throw importError }
    }

    private func buildBackup(in context: NSManagedObjectContext) throws -> LedgerlyBackup {
        let metadata = LedgerlyBackup.Metadata(version: 1, exportedAt: Date())
        return LedgerlyBackup(
            metadata: metadata,
            categories: try exportCategories(in: context),
            wallets: try exportWallets(in: context),
            transactions: try exportTransactions(in: context),
            manualAssets: try exportManualAssets(in: context),
            manualLiabilities: try exportManualLiabilities(in: context),
            budgets: try exportBudgets(in: context),
            goals: try exportGoals(in: context),
            netWorthSnapshots: try exportNetWorthSnapshots(in: context),
            investmentAccounts: try exportInvestmentAccounts(in: context),
            investmentAssets: try exportInvestmentAssets(in: context),
            holdingLots: try exportHoldingLots(in: context),
            priceSnapshots: try exportPriceSnapshots(in: context),
            holdingSales: try exportHoldingSales(in: context)
        )
    }

    private func exportCategories(in context: NSManagedObjectContext) throws -> [LedgerlyBackup.CategoryRecord] {
        let request: NSFetchRequest<Category> = Category.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Category.sortOrder, ascending: true)]
        return try context.fetch(request).map {
            LedgerlyBackup.CategoryRecord(
                identifier: $0.identifier ?? UUID().uuidString,
                name: $0.name ?? "",
                type: $0.type ?? "expense",
                colorHex: $0.colorHex,
                iconName: $0.iconName,
                sortOrder: $0.sortOrder
            )
        }
    }

    private func exportWallets(in context: NSManagedObjectContext) throws -> [LedgerlyBackup.WalletRecord] {
        let request: NSFetchRequest<Wallet> = Wallet.fetchRequest()
        return try context.fetch(request).map {
            LedgerlyBackup.WalletRecord(
                identifier: $0.identifier ?? UUID().uuidString,
                name: $0.name ?? "",
                walletType: $0.walletType ?? "custom",
                baseCurrencyCode: $0.baseCurrencyCode ?? "USD",
                iconName: $0.iconName,
                startingBalance: ($0.startingBalance as Decimal?) ?? .zero,
                currentBalance: ($0.currentBalance as Decimal?) ?? .zero,
                includeInNetWorth: $0.includeInNetWorth,
                archived: $0.archived,
                sortOrder: $0.sortOrder,
                createdAt: $0.createdAt,
                updatedAt: $0.updatedAt
            )
        }
    }

    private func exportTransactions(in context: NSManagedObjectContext) throws -> [LedgerlyBackup.TransactionRecord] {
        let request: NSFetchRequest<Transaction> = Transaction.fetchRequest()
        return try context.fetch(request).map {
            LedgerlyBackup.TransactionRecord(
                identifier: $0.identifier ?? UUID().uuidString,
                direction: $0.direction ?? "expense",
                amount: ($0.amount as Decimal?) ?? .zero,
                currencyCode: $0.currencyCode ?? "USD",
                convertedAmountBase: ($0.convertedAmountBase as Decimal?) ?? .zero,
                date: $0.date ?? Date(),
                notes: $0.notes,
                walletIdentifier: $0.wallet?.identifier,
                categoryIdentifier: $0.category?.identifier,
                isTransfer: $0.isTransfer,
                counterpartyWalletIdentifier: $0.counterpartyWallet?.identifier
            )
        }
    }

    private func exportManualAssets(in context: NSManagedObjectContext) throws -> [LedgerlyBackup.ManualAssetRecord] {
        let request: NSFetchRequest<ManualAsset> = ManualAsset.fetchRequest()
        return try context.fetch(request).map {
            LedgerlyBackup.ManualAssetRecord(
                identifier: $0.identifier ?? UUID().uuidString,
                name: $0.name ?? "",
                type: $0.type ?? "tangible",
                value: ($0.value as Decimal?) ?? .zero,
                currencyCode: $0.currencyCode ?? "USD",
                valuationDate: $0.valuationDate,
                includeInCore: $0.includeInCore,
                includeInTangible: $0.includeInTangible,
                volatility: $0.volatility
            )
        }
    }

    private func exportManualLiabilities(in context: NSManagedObjectContext) throws -> [LedgerlyBackup.ManualLiabilityRecord] {
        let request: NSFetchRequest<ManualLiability> = ManualLiability.fetchRequest()
        return try context.fetch(request).map {
            LedgerlyBackup.ManualLiabilityRecord(
                identifier: $0.identifier ?? UUID().uuidString,
                name: $0.name ?? "",
                type: $0.type ?? "loan",
                balance: ($0.balance as Decimal?) ?? .zero,
                currencyCode: $0.currencyCode ?? "USD",
                dueDate: $0.dueDate
            )
        }
    }

    private func exportBudgets(in context: NSManagedObjectContext) throws -> [LedgerlyBackup.BudgetRecord] {
        let request: NSFetchRequest<MonthlyBudget> = MonthlyBudget.fetchRequest()
        return try context.fetch(request).map {
            LedgerlyBackup.BudgetRecord(
                identifier: $0.identifier ?? UUID().uuidString,
                categoryIdentifier: $0.category?.identifier,
                month: $0.month,
                year: $0.year,
                limitAmount: ($0.limitAmount as Decimal?) ?? .zero,
                currencyCode: $0.currencyCode ?? "USD",
                autoReset: $0.autoReset,
                carryOverAmount: $0.carryOverAmount as Decimal?,
                alert50Sent: $0.alert50Sent,
                alert80Sent: $0.alert80Sent,
                alert100Sent: $0.alert100Sent
            )
        }
    }

    private func exportGoals(in context: NSManagedObjectContext) throws -> [LedgerlyBackup.GoalRecord] {
        let request: NSFetchRequest<SavingGoal> = SavingGoal.fetchRequest()
        return try context.fetch(request).map {
            LedgerlyBackup.GoalRecord(
                identifier: $0.identifier ?? UUID().uuidString,
                name: $0.name ?? "",
                targetAmount: ($0.targetAmount as Decimal?) ?? .zero,
                currencyCode: $0.currencyCode ?? "USD",
                currentAmount: ($0.currentAmount as Decimal?) ?? .zero,
                deadline: $0.deadline,
                status: $0.status ?? "active",
                walletIdentifier: $0.wallet?.identifier,
                categoryIdentifier: $0.category?.identifier
            )
        }
    }

    private func exportNetWorthSnapshots(in context: NSManagedObjectContext) throws -> [LedgerlyBackup.NetWorthSnapshotRecord] {
        let request: NSFetchRequest<NetWorthSnapshot> = NetWorthSnapshot.fetchRequest()
        return try context.fetch(request).map {
            LedgerlyBackup.NetWorthSnapshotRecord(
                identifier: $0.identifier ?? UUID().uuidString,
                timestamp: $0.timestamp ?? Date(),
                totalAssets: ($0.totalAssets as Decimal?) ?? .zero,
                totalLiabilities: ($0.totalLiabilities as Decimal?) ?? .zero,
                coreNetWorth: ($0.coreNetWorth as Decimal?) ?? .zero,
                tangibleNetWorth: ($0.tangibleNetWorth as Decimal?) ?? .zero,
                volatileAssets: ($0.volatileAssets as Decimal?) ?? .zero,
                notes: $0.notes
            )
        }
    }

    private func exportInvestmentAccounts(in context: NSManagedObjectContext) throws -> [LedgerlyBackup.InvestmentAccountRecord] {
        let request: NSFetchRequest<InvestmentAccount> = InvestmentAccount.fetchRequest()
        return try context.fetch(request).map {
            LedgerlyBackup.InvestmentAccountRecord(
                identifier: $0.identifier ?? UUID().uuidString,
                name: $0.name ?? "",
                institution: $0.institution,
                accountType: $0.accountType ?? "brokerage",
                currencyCode: $0.currencyCode ?? "USD",
                includeInNetWorth: $0.includeInNetWorth,
                createdAt: $0.createdAt,
                updatedAt: $0.updatedAt
            )
        }
    }

    private func exportInvestmentAssets(in context: NSManagedObjectContext) throws -> [LedgerlyBackup.InvestmentAssetRecord] {
        let request: NSFetchRequest<InvestmentAsset> = InvestmentAsset.fetchRequest()
        return try context.fetch(request).map {
            LedgerlyBackup.InvestmentAssetRecord(
                identifier: $0.identifier ?? UUID().uuidString,
                symbol: $0.symbol ?? "",
                assetType: $0.assetType ?? "stock",
                name: $0.name ?? "",
                exchange: $0.exchange,
                currencyCode: $0.currencyCode ?? "USD"
            )
        }
    }

    private func exportHoldingLots(in context: NSManagedObjectContext) throws -> [LedgerlyBackup.HoldingLotRecord] {
        let request: NSFetchRequest<HoldingLot> = HoldingLot.fetchRequest()
        return try context.fetch(request).map {
            LedgerlyBackup.HoldingLotRecord(
                identifier: $0.identifier ?? UUID().uuidString,
                quantity: ($0.quantity as Decimal?) ?? .zero,
                costPerUnit: ($0.costPerUnit as Decimal?) ?? .zero,
                acquiredDate: $0.acquiredDate ?? Date(),
                notes: $0.notes,
                fee: $0.fee as Decimal?,
                accountIdentifier: $0.account?.identifier,
                assetIdentifier: $0.asset?.identifier
            )
        }
    }

    private func exportPriceSnapshots(in context: NSManagedObjectContext) throws -> [LedgerlyBackup.PriceSnapshotRecord] {
        let request: NSFetchRequest<PriceSnapshot> = PriceSnapshot.fetchRequest()
        return try context.fetch(request).map {
            LedgerlyBackup.PriceSnapshotRecord(
                identifier: $0.identifier ?? UUID().uuidString,
                assetIdentifier: $0.asset?.identifier,
                price: ($0.price as Decimal?) ?? .zero,
                currencyCode: $0.currencyCode ?? "USD",
                provider: $0.provider ?? "",
                timestamp: $0.timestamp ?? Date(),
                isStale: $0.isStale
            )
        }
    }

    private func exportHoldingSales(in context: NSManagedObjectContext) throws -> [LedgerlyBackup.HoldingSaleRecord] {
        let request: NSFetchRequest<HoldingSale> = HoldingSale.fetchRequest()
        return try context.fetch(request).map {
            LedgerlyBackup.HoldingSaleRecord(
                identifier: $0.identifier ?? UUID().uuidString,
                lotIdentifier: $0.lot?.identifier,
                date: $0.date ?? Date(),
                quantity: ($0.quantity as Decimal?) ?? .zero,
                price: ($0.price as Decimal?) ?? .zero,
                walletName: $0.walletName
            )
        }
    }

    private func apply(backup: LedgerlyBackup, in context: NSManagedObjectContext) throws {
        try importCategories(backup.categories, in: context)
        try importWallets(backup.wallets, in: context)
        try importTransactions(backup.transactions, in: context)
        try importManualAssets(backup.manualAssets, in: context)
        try importManualLiabilities(backup.manualLiabilities, in: context)
        try importBudgets(backup.budgets, in: context)
        try importGoals(backup.goals, in: context)
        try importNetWorthSnapshots(backup.netWorthSnapshots, in: context)
        try importInvestmentAssets(backup.investmentAssets, in: context)
        try importInvestmentAccounts(backup.investmentAccounts, in: context)
        try importHoldingLots(backup.holdingLots, in: context)
        try importPriceSnapshots(backup.priceSnapshots, in: context)
        try importHoldingSales(backup.holdingSales, in: context)
    }

    private func importCategories(_ records: [LedgerlyBackup.CategoryRecord], in context: NSManagedObjectContext) throws {
        for record in records {
            let category = try fetchEntity(Category.self, identifier: record.identifier, in: context) ?? Category(context: context)
            category.identifier = record.identifier
            category.name = record.name
            category.type = record.type
            category.colorHex = record.colorHex
            category.iconName = record.iconName
            category.sortOrder = record.sortOrder
            category.createdAt = category.createdAt ?? Date()
            category.updatedAt = Date()
        }
    }

    private func importWallets(_ records: [LedgerlyBackup.WalletRecord], in context: NSManagedObjectContext) throws {
        for record in records {
            let wallet = try fetchEntity(Wallet.self, identifier: record.identifier, in: context) ?? Wallet(context: context)
            wallet.identifier = record.identifier
            wallet.name = record.name
            wallet.walletType = record.walletType
            wallet.baseCurrencyCode = record.baseCurrencyCode
            wallet.iconName = record.iconName
            wallet.startingBalance = NSDecimalNumber(decimal: record.startingBalance)
            wallet.currentBalance = NSDecimalNumber(decimal: record.currentBalance)
            wallet.includeInNetWorth = record.includeInNetWorth
            wallet.archived = record.archived
            wallet.sortOrder = record.sortOrder
            wallet.createdAt = record.createdAt ?? wallet.createdAt ?? Date()
            wallet.updatedAt = record.updatedAt ?? Date()
        }
    }

    private func importTransactions(_ records: [LedgerlyBackup.TransactionRecord], in context: NSManagedObjectContext) throws {
        for record in records {
            let transaction = try fetchEntity(Transaction.self, identifier: record.identifier, in: context) ?? Transaction(context: context)
            transaction.identifier = record.identifier
            transaction.direction = record.direction
            transaction.amount = NSDecimalNumber(decimal: record.amount)
            transaction.currencyCode = record.currencyCode
            transaction.convertedAmountBase = NSDecimalNumber(decimal: record.convertedAmountBase)
            transaction.date = record.date
            transaction.notes = record.notes
            transaction.isTransfer = record.isTransfer
            if let walletID = record.walletIdentifier {
                transaction.wallet = try fetchEntity(Wallet.self, identifier: walletID, in: context)
            }
            if let categoryID = record.categoryIdentifier {
                transaction.category = try fetchEntity(Category.self, identifier: categoryID, in: context)
            }
            if let peerID = record.counterpartyWalletIdentifier {
                transaction.counterpartyWallet = try fetchEntity(Wallet.self, identifier: peerID, in: context)
            }
        }
    }

    private func importManualAssets(_ records: [LedgerlyBackup.ManualAssetRecord], in context: NSManagedObjectContext) throws {
        for record in records {
            let asset = try fetchEntity(ManualAsset.self, identifier: record.identifier, in: context) ?? ManualAsset(context: context)
            asset.identifier = record.identifier
            asset.name = record.name
            asset.type = record.type
            asset.value = NSDecimalNumber(decimal: record.value)
            asset.currencyCode = record.currencyCode
            asset.valuationDate = record.valuationDate
            asset.includeInCore = record.includeInCore
            asset.includeInTangible = record.includeInTangible
            asset.volatility = record.volatility
        }
    }

    private func importManualLiabilities(_ records: [LedgerlyBackup.ManualLiabilityRecord], in context: NSManagedObjectContext) throws {
        for record in records {
            let liability = try fetchEntity(ManualLiability.self, identifier: record.identifier, in: context) ?? ManualLiability(context: context)
            liability.identifier = record.identifier
            liability.name = record.name
            liability.type = record.type
            liability.balance = NSDecimalNumber(decimal: record.balance)
            liability.currencyCode = record.currencyCode
            liability.dueDate = record.dueDate
        }
    }

    private func importBudgets(_ records: [LedgerlyBackup.BudgetRecord], in context: NSManagedObjectContext) throws {
        for record in records {
            let budget = try fetchEntity(MonthlyBudget.self, identifier: record.identifier, in: context) ?? MonthlyBudget(context: context)
            budget.identifier = record.identifier
            budget.month = record.month
            budget.year = record.year
            budget.limitAmount = NSDecimalNumber(decimal: record.limitAmount)
            budget.currencyCode = record.currencyCode
            budget.autoReset = record.autoReset
            if let carry = record.carryOverAmount {
                budget.carryOverAmount = NSDecimalNumber(decimal: carry)
            } else {
                budget.carryOverAmount = nil
            }
            budget.alert50Sent = record.alert50Sent
            budget.alert80Sent = record.alert80Sent
            budget.alert100Sent = record.alert100Sent
            if let categoryID = record.categoryIdentifier {
                budget.category = try fetchEntity(Category.self, identifier: categoryID, in: context)
            }
        }
    }

    private func importGoals(_ records: [LedgerlyBackup.GoalRecord], in context: NSManagedObjectContext) throws {
        for record in records {
            let goal = try fetchEntity(SavingGoal.self, identifier: record.identifier, in: context) ?? SavingGoal(context: context)
            goal.identifier = record.identifier
            goal.name = record.name
            goal.targetAmount = NSDecimalNumber(decimal: record.targetAmount)
            goal.currencyCode = record.currencyCode
            goal.currentAmount = NSDecimalNumber(decimal: record.currentAmount)
            goal.deadline = record.deadline
            goal.status = record.status
            if let walletID = record.walletIdentifier {
                goal.wallet = try fetchEntity(Wallet.self, identifier: walletID, in: context)
            }
            if let categoryID = record.categoryIdentifier {
                goal.category = try fetchEntity(Category.self, identifier: categoryID, in: context)
            }
        }
    }

    private func importNetWorthSnapshots(_ records: [LedgerlyBackup.NetWorthSnapshotRecord], in context: NSManagedObjectContext) throws {
        for record in records {
            let snapshot = try fetchEntity(NetWorthSnapshot.self, identifier: record.identifier, in: context) ?? NetWorthSnapshot(context: context)
            snapshot.identifier = record.identifier
            snapshot.timestamp = record.timestamp
            snapshot.totalAssets = NSDecimalNumber(decimal: record.totalAssets)
            snapshot.totalLiabilities = NSDecimalNumber(decimal: record.totalLiabilities)
            snapshot.coreNetWorth = NSDecimalNumber(decimal: record.coreNetWorth)
            snapshot.tangibleNetWorth = NSDecimalNumber(decimal: record.tangibleNetWorth)
            snapshot.volatileAssets = NSDecimalNumber(decimal: record.volatileAssets)
            snapshot.notes = record.notes
        }
    }

    private func importInvestmentAssets(_ records: [LedgerlyBackup.InvestmentAssetRecord], in context: NSManagedObjectContext) throws {
        for record in records {
            let asset = try fetchEntity(InvestmentAsset.self, identifier: record.identifier, in: context) ?? InvestmentAsset(context: context)
            asset.identifier = record.identifier
            asset.symbol = record.symbol
            asset.assetType = record.assetType
            asset.name = record.name
            asset.exchange = record.exchange
            asset.currencyCode = record.currencyCode
        }
    }

    private func importInvestmentAccounts(_ records: [LedgerlyBackup.InvestmentAccountRecord], in context: NSManagedObjectContext) throws {
        for record in records {
            let account = try fetchEntity(InvestmentAccount.self, identifier: record.identifier, in: context) ?? InvestmentAccount(context: context)
            account.identifier = record.identifier
            account.name = record.name
            account.institution = record.institution
            account.accountType = record.accountType
            account.currencyCode = record.currencyCode
            account.includeInNetWorth = record.includeInNetWorth
            account.createdAt = record.createdAt ?? account.createdAt ?? Date()
            account.updatedAt = record.updatedAt ?? Date()
        }
    }

    private func importHoldingLots(_ records: [LedgerlyBackup.HoldingLotRecord], in context: NSManagedObjectContext) throws {
        for record in records {
            let lot = try fetchEntity(HoldingLot.self, identifier: record.identifier, in: context) ?? HoldingLot(context: context)
            lot.identifier = record.identifier
            lot.quantity = NSDecimalNumber(decimal: record.quantity)
            lot.costPerUnit = NSDecimalNumber(decimal: record.costPerUnit)
            lot.acquiredDate = record.acquiredDate
            lot.notes = record.notes
            if let fee = record.fee {
                lot.fee = NSDecimalNumber(decimal: fee)
            } else {
                lot.fee = nil
            }
            if let accountID = record.accountIdentifier {
                lot.account = try fetchEntity(InvestmentAccount.self, identifier: accountID, in: context)
            }
            if let assetID = record.assetIdentifier {
                lot.asset = try fetchEntity(InvestmentAsset.self, identifier: assetID, in: context)
            }
        }
    }

    private func importPriceSnapshots(_ records: [LedgerlyBackup.PriceSnapshotRecord], in context: NSManagedObjectContext) throws {
        for record in records {
            let snapshot = try fetchEntity(PriceSnapshot.self, identifier: record.identifier, in: context) ?? PriceSnapshot(context: context)
            snapshot.identifier = record.identifier
            snapshot.price = NSDecimalNumber(decimal: record.price)
            snapshot.currencyCode = record.currencyCode
            snapshot.provider = record.provider
            snapshot.timestamp = record.timestamp
            snapshot.isStale = record.isStale
            if let assetID = record.assetIdentifier {
                snapshot.asset = try fetchEntity(InvestmentAsset.self, identifier: assetID, in: context)
            }
        }
    }

    private func importHoldingSales(_ records: [LedgerlyBackup.HoldingSaleRecord], in context: NSManagedObjectContext) throws {
        for record in records {
            let sale = try fetchEntity(HoldingSale.self, identifier: record.identifier, in: context) ?? HoldingSale(context: context)
            sale.identifier = record.identifier
            sale.date = record.date
            sale.quantity = NSDecimalNumber(decimal: record.quantity)
            sale.price = NSDecimalNumber(decimal: record.price)
            sale.walletName = record.walletName
            if let lotID = record.lotIdentifier {
                sale.lot = try fetchEntity(HoldingLot.self, identifier: lotID, in: context)
            }
        }
    }

    private func fetchEntity<T: NSManagedObject>(_ type: T.Type, identifier: String, in context: NSManagedObjectContext) throws -> T? {
        let request = NSFetchRequest<T>(entityName: String(describing: type))
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "identifier == %@", identifier)
        return try context.fetch(request).first
    }
}
