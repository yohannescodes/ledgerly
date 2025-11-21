import CoreData
import Foundation

struct MonthlyBudgetModel: Identifiable, Hashable {
    let id: NSManagedObjectID
    let identifier: String
    let month: Int
    let year: Int
    let limitAmount: Decimal
    let currencyCode: String
    let spentAmount: Decimal
    let categoryName: String
}

struct SavingGoalModel: Identifiable, Hashable {
    let id: NSManagedObjectID
    let identifier: String
    let name: String
    let targetAmount: Decimal
    let currencyCode: String
    let currentAmount: Decimal
    let deadline: Date?
    let status: String
    let progress: Decimal
}

extension MonthlyBudgetModel {
    init(managedObject: MonthlyBudget, spent: Decimal, categoryName: String) {
        id = managedObject.objectID
        identifier = managedObject.identifier ?? UUID().uuidString
        month = Int(managedObject.month)
        year = Int(managedObject.year)
        limitAmount = managedObject.limitAmount as Decimal? ?? .zero
        currencyCode = managedObject.currencyCode ?? "USD"
        spentAmount = spent
        self.categoryName = categoryName
    }
}

extension SavingGoalModel {
    init(managedObject: SavingGoal) {
        id = managedObject.objectID
        identifier = managedObject.identifier ?? UUID().uuidString
        name = managedObject.name ?? "Goal"
        targetAmount = managedObject.targetAmount as Decimal? ?? .zero
        currencyCode = managedObject.currencyCode ?? "USD"
        currentAmount = managedObject.currentAmount as Decimal? ?? .zero
        deadline = managedObject.deadline
        status = managedObject.status ?? "active"
        progress = targetAmount == .zero ? 0 : (currentAmount / targetAmount) * 100
    }
}

extension MonthlyBudget {
    static func create(
        in context: NSManagedObjectContext,
        category: Category?,
        month: Int,
        year: Int,
        limit: Decimal,
        currencyCode: String
    ) -> MonthlyBudget {
        let budget = MonthlyBudget(context: context)
        budget.identifier = UUID().uuidString
        budget.category = category
        budget.month = Int16(month)
        budget.year = Int16(year)
        budget.limitAmount = NSDecimalNumber(decimal: limit)
        budget.currencyCode = currencyCode
        budget.autoReset = true
        return budget
    }
}

extension SavingGoal {
    static func create(
        in context: NSManagedObjectContext,
        name: String,
        target: Decimal,
        currencyCode: String,
        linkedWallet: Wallet?
    ) -> SavingGoal {
        let goal = SavingGoal(context: context)
        goal.identifier = UUID().uuidString
        goal.name = name
        goal.targetAmount = NSDecimalNumber(decimal: target)
        goal.currencyCode = currencyCode
        goal.currentAmount = 0
        goal.deadline = Calendar.current.date(byAdding: .month, value: 6, to: Date())
        goal.status = "active"
        goal.wallet = linkedWallet
        return goal
    }
}
