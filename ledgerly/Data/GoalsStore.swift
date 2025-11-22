import CoreData
import Foundation
import SwiftUI
import Combine

@MainActor
final class GoalsStore: ObservableObject {
    @Published private(set) var goals: [SavingGoalModel] = []

    private let persistence: PersistenceController

    init(persistence: PersistenceController) {
        self.persistence = persistence
        reload()
    }

    func reload() {
        let context = persistence.container.viewContext
        let request: NSFetchRequest<SavingGoal> = SavingGoal.fetchRequest()
        do {
            let goals = try context.fetch(request)
            self.goals = goals.map(SavingGoalModel.init)
        } catch {
            assertionFailure("Failed to fetch goals: \(error)")
            goals = []
        }
    }
    func createGoal(input: SavingGoalFormInput) {
        let context = persistence.newBackgroundContext()
        context.perform {
            let wallet = input.walletID.flatMap { try? context.existingObject(with: $0) as? Wallet }
            let category = input.categoryID.flatMap { try? context.existingObject(with: $0) as? Category }
            let goal = SavingGoal.create(
                in: context,
                name: input.name,
                target: input.targetAmount,
                currencyCode: input.currencyCode,
                deadline: input.deadline,
                linkedWallet: wallet,
                linkedCategory: category
            )
            try? context.save()
            if let deadline = goal.deadline {
                GoalReminderService().scheduleReminder(payload: .init(goalName: goal.name ?? "Goal", deadline: deadline))
            }
            Task { @MainActor in self.reload() }
        }
    }

    func recordContribution(goalID: NSManagedObjectID, amountDelta: Decimal) {
        performWrite(goalID: goalID) { goal in
            let current = (goal.currentAmount as Decimal? ?? .zero) + amountDelta
            let clamped = max(current, 0)
            let target = goal.targetAmount as Decimal? ?? .zero
            let capped = target > .zero ? min(clamped, target) : clamped
            goal.currentAmount = NSDecimalNumber(decimal: capped)
            self.updateStatus(for: goal, targetAmount: target)
        }
    }

    func markGoalCompleted(goalID: NSManagedObjectID) {
        performWrite(goalID: goalID) { goal in
            goal.currentAmount = goal.targetAmount
            goal.status = "completed"
        }
    }

    func reopenGoal(goalID: NSManagedObjectID) {
        performWrite(goalID: goalID) { goal in
            goal.status = "active"
        }
    }

    func deleteGoal(goalID: NSManagedObjectID) {
        let context = persistence.newBackgroundContext()
        context.perform {
            guard let goal = try? context.existingObject(with: goalID) as? SavingGoal else { return }
            context.delete(goal)
            try? context.save()
            Task { @MainActor in self.reload() }
        }
    }

    private func performWrite(goalID: NSManagedObjectID, mutate: @escaping (SavingGoal) -> Void) {
        let context = persistence.newBackgroundContext()
        context.perform {
            guard let goal = try? context.existingObject(with: goalID) as? SavingGoal else { return }
            mutate(goal)
            try? context.save()
            Task { @MainActor in self.reload() }
        }
    }

    private func updateStatus(for goal: SavingGoal, targetAmount: Decimal) {
        let current = goal.currentAmount as Decimal? ?? .zero
        if targetAmount > .zero, current >= targetAmount {
            goal.status = "completed"
        } else if goal.status == "completed" {
            goal.status = "active"
        }
    }
}
