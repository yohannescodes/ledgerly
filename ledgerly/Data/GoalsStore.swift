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
                currencyCode: Locale.current.currency?.identifier ?? "USD",
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
}
