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
}
