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
    let categoryID: NSManagedObjectID?
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
        self.categoryID = managedObject.category?.objectID
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
    }
}

extension SavingGoalModel {
    /// Returns the goal's completion between 0 and 1, clamped for invalid values.
    var progressFraction: Double {
        let targetAmountNumber = NSDecimalNumber(decimal: targetAmount)
        guard targetAmountNumber != .zero else { return 0 }
        let currentAmountNumber = NSDecimalNumber(decimal: currentAmount)
        let ratio = currentAmountNumber.dividing(by: targetAmountNumber).doubleValue
        return min(max(ratio, 0), 1)
    }

    /// Convenience for displaying a percentage (0 - 100) derived from ``progressFraction``.
    var progressPercentage: Int {
        Int(progressFraction * 100)
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
        deadline: Date,
        linkedWallet: Wallet?,
        linkedCategory: Category?
    ) -> SavingGoal {
        let goal = SavingGoal(context: context)
        goal.identifier = UUID().uuidString
        goal.name = name
        goal.targetAmount = NSDecimalNumber(decimal: target)
        goal.currencyCode = currencyCode
        goal.currentAmount = 0
        goal.deadline = deadline
        goal.status = "active"
        goal.wallet = linkedWallet
        goal.category = linkedCategory
        return goal
    }
}
