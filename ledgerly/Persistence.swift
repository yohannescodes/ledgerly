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
        ensureBaseEntities()
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

    private func ensureBaseEntities() {
        let context = container.viewContext
        context.perform {
            if AppSettings.fetchSingleton(in: context) == nil {
                _ = AppSettings.makeDefault(in: context)
            }
            CategoryDefaults.ensureDefaults(in: context)
            self.mergeDuplicateCategories(in: context)
            self.markBalanceAdjustmentsNonAffecting(in: context)
            do {
                try context.save()
            } catch {
                assertionFailure("Failed to ensure base entities: \(error)")
            }
        }
    }

    private func seedNetWorthSnapshotIfNeeded(in context: NSManagedObjectContext) {
        let snapshotRequest: NSFetchRequest<NetWorthSnapshot> = NetWorthSnapshot.fetchRequest()
        snapshotRequest.fetchLimit = 1
        let count = (try? context.count(for: snapshotRequest)) ?? 0
        guard count == 0 else { return }
        let service = NetWorthService(persistence: self)
        let totals = service.computeTotals()
        let converter = CurrencyConverter.fromSettings(in: context)
        let exchangeMode = ExchangeMode(storedValue: AppSettings.fetchSingleton(in: context)?.exchangeMode)
        _ = NetWorthSnapshot.create(
            in: context,
            totalAssets: totals.totalAssets,
            totalLiabilities: totals.totalLiabilities,
            coreNetWorth: totals.coreNetWorth,
            tangibleNetWorth: totals.tangibleNetWorth,
            volatileAssets: totals.volatileAssets,
            currencyCode: converter.baseCurrency,
            exchangeModeUsed: exchangeMode.rawValue
        )
    }

    private func markBalanceAdjustmentsNonAffecting(in context: NSManagedObjectContext) {
        let request: NSFetchRequest<Transaction> = Transaction.fetchRequest()
        request.predicate = NSPredicate(format: "notes == %@ AND affectsBalance == YES", "Balance adjustment")
        guard let transactions = try? context.fetch(request), !transactions.isEmpty else { return }
        for transaction in transactions {
            transaction.affectsBalance = false
        }
    }

    private func mergeDuplicateCategories(in context: NSManagedObjectContext) {
        let request: NSFetchRequest<Category> = Category.fetchRequest()
        guard let categories = try? context.fetch(request), categories.count > 1 else { return }
        var grouped: [String: [Category]] = [:]
        for category in categories {
            let key = normalizedCategoryName(category.name)
            guard !key.isEmpty else { continue }
            grouped[key, default: []].append(category)
        }
        for group in grouped.values where group.count > 1 {
            mergeCategoryGroup(group, in: context)
        }
    }

    private func mergeCategoryGroup(_ categories: [Category], in context: NSManagedObjectContext) {
        guard let primary = selectPrimaryCategory(from: categories) else { return }
        let duplicates = categories.filter { $0.objectID != primary.objectID }
        let minSortOrder = categories.map(\.sortOrder).min() ?? primary.sortOrder
        primary.sortOrder = minSortOrder
        for duplicate in duplicates {
            mergeCategoryAttributes(from: duplicate, into: primary)
            reassignCategoryReferences(from: duplicate, to: primary)
            context.delete(duplicate)
        }
    }

    private func selectPrimaryCategory(from categories: [Category]) -> Category? {
        categories.sorted { lhs, rhs in
            let lhsUsage = categoryUsageCount(lhs)
            let rhsUsage = categoryUsageCount(rhs)
            if lhsUsage != rhsUsage { return lhsUsage > rhsUsage }
            if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
            let lhsDate = lhs.createdAt ?? .distantFuture
            let rhsDate = rhs.createdAt ?? .distantFuture
            if lhsDate != rhsDate { return lhsDate < rhsDate }
            return lhs.objectID.uriRepresentation().absoluteString < rhs.objectID.uriRepresentation().absoluteString
        }.first
    }

    private func mergeCategoryAttributes(from source: Category, into destination: Category) {
        if destination.name?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true,
           let name = source.name,
           !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            destination.name = name
        }
        if destination.type?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true,
           let type = source.type,
           !type.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            destination.type = type
        }
        if destination.colorHex?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true,
           let colorHex = source.colorHex,
           !colorHex.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            destination.colorHex = colorHex
        }
        if destination.iconName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true,
           let iconName = source.iconName,
           !iconName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            destination.iconName = iconName
        }
        if let sourceCreatedAt = source.createdAt {
            if let destinationCreatedAt = destination.createdAt {
                destination.createdAt = min(destinationCreatedAt, sourceCreatedAt)
            } else {
                destination.createdAt = sourceCreatedAt
            }
        }
        destination.updatedAt = Date()
    }

    private func reassignCategoryReferences(from source: Category, to destination: Category) {
        let transactions = (source.transactions as? Set<Transaction>) ?? []
        for transaction in transactions {
            transaction.category = destination
        }
        let budgets = (source.budgets as? Set<MonthlyBudget>) ?? []
        for budget in budgets {
            budget.category = destination
        }
        let goals = (source.goals as? Set<SavingGoal>) ?? []
        for goal in goals {
            goal.category = destination
        }
    }

    private func categoryUsageCount(_ category: Category) -> Int {
        let transactions = (category.transactions as? Set<Transaction>)?.count ?? 0
        let budgets = (category.budgets as? Set<MonthlyBudget>)?.count ?? 0
        let goals = (category.goals as? Set<SavingGoal>)?.count ?? 0
        return transactions + budgets + goals
    }

    private func normalizedCategoryName(_ name: String?) -> String {
        (name ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

}
