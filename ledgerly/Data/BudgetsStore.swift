import CoreData
import Foundation
import SwiftUI
import Combine

@MainActor
final class BudgetsStore: ObservableObject {
    @Published private(set) var budgets: [MonthlyBudgetModel] = []
    
    private let persistence: PersistenceController
    
    init(persistence: PersistenceController) {
        self.persistence = persistence
        reload()
    }
    
    func reload() {
        let context = persistence.container.viewContext
        let request: NSFetchRequest<MonthlyBudget> = MonthlyBudget.fetchRequest()
        do {
            let budgets = try context.fetch(request)
            self.budgets = budgets.map { budget in
                let spent = self.calculateSpent(for: budget, in: context)
                handleAlerts(for: budget, spent: spent)
                let name = budget.category?.name ?? "Category"
                return MonthlyBudgetModel(managedObject: budget, spent: spent, categoryName: name)
            }
            try context.save()
        } catch {
            assertionFailure("Failed to fetch budgets: \(error)")
            budgets = []
        }
    }
    
    private func calculateSpent(for budget: MonthlyBudget, in context: NSManagedObjectContext) -> Decimal {
        guard let category = budget.category else { return .zero }
        let request: NSFetchRequest<Transaction> = Transaction.fetchRequest()
        let startComponents = DateComponents(year: Int(budget.year), month: Int(budget.month), day: 1)
        guard let startDate = Calendar.current.date(from: startComponents) else { return .zero }
        let endDate = Calendar.current.date(byAdding: .month, value: 1, to: startDate) ?? Date()
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "category == %@", category),
            NSPredicate(format: "date >= %@ AND date < %@", startDate as NSDate, endDate as NSDate),
            NSPredicate(format: "direction == %@", "expense")
        ])
        do {
            let transactions = try context.fetch(request)
            return transactions.reduce(.zero) { $0 + ( $1.amount as Decimal? ?? .zero) }
        } catch {
            return .zero
        }
    }
    func createBudget(input: BudgetFormInput) {
        let context = persistence.newBackgroundContext()
        context.perform {
            let category: Category? = input.categoryID.flatMap { try? context.existingObject(with: $0) as? Category }
            _ = MonthlyBudget.create(
                in: context,
                category: category,
                month: Calendar.current.component(.month, from: Date()),
                year: Calendar.current.component(.year, from: Date()),
                limit: input.limitAmount,
                currencyCode: input.currencyCode
            )
            try? context.save()
            Task { @MainActor in self.reload() }
        }
    }
    
    private func handleAlerts(for budget: MonthlyBudget, spent: Decimal) {
        guard let limit = budget.limitAmount as Decimal? else { return }
        let ratio = limit == .zero ? 0 : (spent / limit)
        let thresholds: [(keyPath: ReferenceWritableKeyPath<MonthlyBudget, Bool>, value: Double)] = [
            (\.alert50Sent, 0.5),
            (\.alert80Sent, 0.8),
            (\.alert100Sent, 1.0)
        ]
        let settings = AppSettings.fetchSingleton(in: budget.managedObjectContext ?? persistence.container.viewContext)
        for threshold in thresholds where ratio >= Decimal(threshold.value) && budget[keyPath: threshold.keyPath] == false {
            budget[keyPath: threshold.keyPath] = true
            let alert = BudgetAlert(context: budget.managedObjectContext ?? persistence.container.viewContext)
            alert.identifier = UUID().uuidString
            alert.timestamp = Date()
            alert.threshold = Int16(threshold.value * 100)
            alert.spentAmount = NSDecimalNumber(decimal: spent)
            alert.budget = budget
            if settings?.notificationsEnabled ?? true {
                BudgetAlertService().scheduleAlert(
                    payload: .init(
                        categoryName: budget.category?.name ?? "Budget",
                        threshold: Int(threshold.value * 100),
                        spentAmount: spent,
                        budgetID: budget.objectID
                    )
                )
            }
        }
    }
    func updateBudget(budgetID: NSManagedObjectID, input: BudgetFormInput) {
        let context = persistence.newBackgroundContext()
        context.perform {
            guard let budget = try? context.existingObject(with: budgetID) as? MonthlyBudget else { return }
            budget.limitAmount = NSDecimalNumber(decimal: input.limitAmount)
            budget.currencyCode = input.currencyCode
            budget.month = Int16(input.month)
            budget.year = Int16(input.year)
            if let categoryID = input.categoryID, let category = try? context.existingObject(with: categoryID) as? Category {
                budget.category = category
            }
            try? context.save()
            Task { @MainActor in self.reload() }
        }
    }
}
