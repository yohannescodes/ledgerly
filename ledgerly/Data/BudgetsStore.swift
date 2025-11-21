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
                let name = budget.category?.name ?? "Category"
                return MonthlyBudgetModel(managedObject: budget, spent: spent, categoryName: name)
            }
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
}
