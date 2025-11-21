import CoreData
import Foundation
import SwiftUI
import Combine

struct TransactionFilter {
    enum Segment: String, CaseIterable, Identifiable {
        case all
        case expenses
        case income
        case transfers

        var id: String { rawValue }

        var title: String {
            switch self {
            case .all: return "All"
            case .expenses: return "Expenses"
            case .income: return "Income"
            case .transfers: return "Transfers"
            }
        }

        var predicate: NSPredicate? {
            switch self {
            case .all: return nil
            case .expenses: return NSPredicate(format: "direction == %@", "expense")
            case .income: return NSPredicate(format: "direction == %@", "income")
            case .transfers: return NSPredicate(format: "direction == %@", "transfer")
            }
        }
    }

    var segment: Segment = .all
}

struct TransactionSection: Identifiable, Hashable {
    let id: Date
    let date: Date
    let transactions: [TransactionModel]
    let total: Decimal
}

@MainActor
final class TransactionsStore: ObservableObject {
    private let persistence: PersistenceController

    init(persistence: PersistenceController) {
        self.persistence = persistence
    }

    func fetchSections(filter: TransactionFilter) -> [TransactionSection] {
        let context = persistence.container.viewContext
        var sections: [TransactionSection] = []
        context.performAndWait {
            let request = Transaction.fetchRequestAll()
            if let predicate = filter.segment.predicate {
                request.predicate = predicate
            }
            do {
                let results = try context.fetch(request)
                let models = results.map(TransactionModel.init)
                sections = Self.groupTransactions(models)
            } catch {
                assertionFailure("Failed to fetch transactions: \(error)")
            }
        }
        return sections
    }

    private static func groupTransactions(_ transactions: [TransactionModel]) -> [TransactionSection] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: transactions) { transaction in
            calendar.startOfDay(for: transaction.date)
        }
        return grouped
            .map { key, values in
                let total = values.reduce(Decimal.zero) { partialResult, transaction in
                    partialResult + transaction.amount
                }
                return TransactionSection(id: key, date: key, transactions: values, total: total)
            }
            .sorted { $0.date > $1.date }
    }
}
