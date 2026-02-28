import CoreData
import Foundation

enum DataBackupError: Error {
    case buildFailure
    case decodeFailure(Error)
    case importFailure(Error)
}

extension DataBackupError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .buildFailure:
            return "Unable to build backup."
        case .decodeFailure(let error):
            return "Backup file could not be read. \(error.localizedDescription)"
        case .importFailure(let error):
            return "Backup data could not be saved. \(error.localizedDescription)"
        }
    }
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
        let affectsBalance: Bool?
        let walletIdentifier: String?
        let categoryIdentifier: String?
        let isTransfer: Bool
        let counterpartyWalletIdentifier: String?
        let createdAt: Date?
        let updatedAt: Date?
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
        let investmentProvider: String?
        let investmentCoinID: String?
        let investmentSymbol: String?
        let investmentQuantity: Decimal?
        let investmentCostPerUnit: Decimal?
        let investmentContractMultiplier: Decimal?
        let marketPrice: Decimal?
        let marketPriceCurrencyCode: String?
        let marketPriceUpdatedAt: Date?
        let walletIdentifier: String?
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
        let currencyCode: String?
        let exchangeModeUsed: String?
        let totalAssets: Decimal
        let totalLiabilities: Decimal
        let coreNetWorth: Decimal
        let tangibleNetWorth: Decimal
        let volatileAssets: Decimal
        let notes: String?
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
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        let data = try Data(contentsOf: url)
        let backup: LedgerlyBackup
        do {
            backup = try decoder.decode(LedgerlyBackup.self, from: data)
        } catch {
            throw DataBackupError.decodeFailure(error)
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
        if let importError { throw DataBackupError.importFailure(importError) }
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
            netWorthSnapshots: try exportNetWorthSnapshots(in: context)
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
                affectsBalance: $0.affectsBalance,
                walletIdentifier: $0.wallet?.identifier,
                categoryIdentifier: $0.category?.identifier,
                isTransfer: $0.isTransfer,
                counterpartyWalletIdentifier: $0.counterpartyWallet?.identifier,
                createdAt: $0.createdAt,
                updatedAt: $0.updatedAt
            )
        }
    }

    private func exportManualAssets(in context: NSManagedObjectContext) throws -> [LedgerlyBackup.ManualAssetRecord] {
        let request: NSFetchRequest<ManualAsset> = ManualAsset.fetchRequest()
        return try context.fetch(request).map { asset in
            LedgerlyBackup.ManualAssetRecord(
                identifier: asset.identifier ?? UUID().uuidString,
                name: asset.name ?? "",
                type: asset.type ?? "tangible",
                value: (asset.value as Decimal?) ?? .zero,
                currencyCode: asset.currencyCode ?? "USD",
                valuationDate: asset.valuationDate,
                includeInCore: asset.includeInCore,
                includeInTangible: asset.includeInTangible,
                volatility: asset.volatility,
                investmentProvider: asset.investmentProvider,
                investmentCoinID: asset.investmentCoinID,
                investmentSymbol: asset.investmentSymbol,
                investmentQuantity: asset.investmentQuantity as Decimal?,
                investmentCostPerUnit: asset.investmentCostPerUnit as Decimal?,
                investmentContractMultiplier: asset.investmentContractMultiplier as Decimal?,
                marketPrice: asset.marketPrice as Decimal?,
                marketPriceCurrencyCode: asset.marketPriceCurrencyCode,
                marketPriceUpdatedAt: asset.marketPriceUpdatedAt,
                walletIdentifier: asset.wallet?.identifier
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
                currencyCode: $0.currencyCode,
                exchangeModeUsed: $0.exchangeModeUsed,
                totalAssets: ($0.totalAssets as Decimal?) ?? .zero,
                totalLiabilities: ($0.totalLiabilities as Decimal?) ?? .zero,
                coreNetWorth: ($0.coreNetWorth as Decimal?) ?? .zero,
                tangibleNetWorth: ($0.tangibleNetWorth as Decimal?) ?? .zero,
                volatileAssets: ($0.volatileAssets as Decimal?) ?? .zero,
                notes: $0.notes
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
    }

    private func importCategories(_ records: [LedgerlyBackup.CategoryRecord], in context: NSManagedObjectContext) throws {
        let request: NSFetchRequest<Category> = Category.fetchRequest()
        let existing = try context.fetch(request)
        var categoriesByIdentifier: [String: Category] = [:]
        var categoriesBySignature: [String: Category] = [:]

        for category in existing {
            if let identifier = category.identifier {
                categoriesByIdentifier[identifier] = category
            }
            let signature = categorySignature(
                name: category.name,
                type: category.type,
                colorHex: category.colorHex,
                iconName: category.iconName
            )
            if categoriesBySignature[signature] == nil {
                categoriesBySignature[signature] = category
            }
        }

        for record in records {
            let signature = categorySignature(
                name: record.name,
                type: record.type,
                colorHex: record.colorHex,
                iconName: record.iconName
            )
            let category = categoriesByIdentifier[record.identifier]
                ?? categoriesBySignature[signature]
                ?? Category(context: context)
            if category.identifier != record.identifier {
                category.identifier = record.identifier
                categoriesByIdentifier[record.identifier] = category
            }
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
            guard let walletID = record.walletIdentifier,
                  let wallet = try fetchEntity(Wallet.self, identifier: walletID, in: context) else {
                continue
            }
            let transaction = try fetchEntity(Transaction.self, identifier: record.identifier, in: context) ?? Transaction(context: context)
            transaction.identifier = record.identifier
            transaction.direction = record.direction
            transaction.amount = NSDecimalNumber(decimal: record.amount)
            transaction.currencyCode = record.currencyCode
            transaction.convertedAmountBase = NSDecimalNumber(decimal: record.convertedAmountBase)
            transaction.date = record.date
            transaction.notes = record.notes
            transaction.affectsBalance = record.affectsBalance ?? true
            transaction.isTransfer = record.isTransfer
            let fallbackDate = record.date
            transaction.createdAt = record.createdAt ?? transaction.createdAt ?? fallbackDate
            transaction.updatedAt = record.updatedAt ?? fallbackDate
            transaction.wallet = wallet
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
            asset.valuationDate = record.valuationDate ?? Date()
            asset.includeInCore = record.includeInCore
            asset.includeInTangible = record.includeInTangible
            asset.volatility = record.volatility
            let inferredProvider: String?
            if record.investmentProvider == nil, let identifier = record.investmentCoinID {
                inferredProvider = identifier == identifier.uppercased() ? "stock" : "crypto"
            } else {
                inferredProvider = nil
            }
            asset.investmentProvider = record.investmentProvider ?? inferredProvider
            asset.investmentCoinID = record.investmentCoinID
            asset.investmentSymbol = record.investmentSymbol
            if let quantity = record.investmentQuantity {
                asset.investmentQuantity = NSDecimalNumber(decimal: quantity)
            }
            if let cost = record.investmentCostPerUnit {
                asset.investmentCostPerUnit = NSDecimalNumber(decimal: cost)
            }
            if let multiplier = record.investmentContractMultiplier {
                asset.investmentContractMultiplier = NSDecimalNumber(decimal: multiplier)
            }
            if let marketPrice = record.marketPrice {
                asset.marketPrice = NSDecimalNumber(decimal: marketPrice)
            }
            asset.marketPriceCurrencyCode = record.marketPriceCurrencyCode
            asset.marketPriceUpdatedAt = record.marketPriceUpdatedAt
            if let walletID = record.walletIdentifier {
                asset.wallet = try fetchEntity(Wallet.self, identifier: walletID, in: context)
            } else {
                asset.wallet = nil
            }
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
            snapshot.currencyCode = record.currencyCode
            snapshot.exchangeModeUsed = record.exchangeModeUsed
            snapshot.totalAssets = NSDecimalNumber(decimal: record.totalAssets)
            snapshot.totalLiabilities = NSDecimalNumber(decimal: record.totalLiabilities)
            snapshot.coreNetWorth = NSDecimalNumber(decimal: record.coreNetWorth)
            snapshot.tangibleNetWorth = NSDecimalNumber(decimal: record.tangibleNetWorth)
            snapshot.volatileAssets = NSDecimalNumber(decimal: record.volatileAssets)
            snapshot.notes = record.notes
        }
    }

    private func fetchEntity<T: NSManagedObject>(_ type: T.Type, identifier: String, in context: NSManagedObjectContext) throws -> T? {
        let request = NSFetchRequest<T>(entityName: String(describing: type))
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "identifier == %@", identifier)
        return try context.fetch(request).first
    }

    private func categorySignature(name: String?, type: String?, colorHex: String?, iconName: String?) -> String {
        let normalizedName = (name ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedType = (type ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedColor = (colorHex ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedIcon = (iconName ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return "\(normalizedName)|\(normalizedType)|\(normalizedColor)|\(normalizedIcon)"
    }
}
