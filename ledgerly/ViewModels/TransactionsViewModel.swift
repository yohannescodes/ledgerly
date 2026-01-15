import Foundation
import SwiftUI
import Combine

@MainActor
final class TransactionsViewModel: ObservableObject {
    @Published var filter = TransactionFilter()
    @Published private(set) var sections: [TransactionSection] = []
    @Published private(set) var currentMonthTotal: Decimal = .zero
    @Published private(set) var previousMonthTotal: Decimal = .zero
    @Published private(set) var currentIncomeTotal: Decimal = .zero
    @Published private(set) var currentExpenseTotal: Decimal = .zero

    private let store: TransactionsStore

    init(store: TransactionsStore, initialFilter: TransactionFilter = TransactionFilter()) {
        self.store = store
        self.filter = initialFilter
        refresh()
    }

    func refresh() {
        sections = store.fetchSections(filter: filter)
        updateSummaries()
    }

    func updateSegment(_ segment: TransactionFilter.Segment) {
        filter.segment = segment
        refresh()
    }

    func apply(filter: TransactionFilter) {
        self.filter = filter
        refresh()
    }

    func createTransaction(input: TransactionFormInput) {
        store.createTransaction(input: input)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.refresh()
        }
    }

    @discardableResult
    func handle(action: TransactionDetailAction, for model: TransactionModel) -> TransactionModel? {
        switch action {
        case .delete:
            store.deleteTransaction(id: model.id)
            refresh()
            return nil
        case .update(let change):
            let updated = store.updateTransaction(id: model.id, change: change)
            refresh()
            return updated
        case .none:
            return nil
        }
    }

    private func updateSummaries() {
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        let previousMonth = calendar.date(byAdding: .month, value: -1, to: startOfMonth) ?? now
        currentMonthTotal = totalAmount(from: startOfMonth, to: now)
        previousMonthTotal = totalAmount(from: previousMonth, to: startOfMonth)
        let allTransactions = sections.flatMap { $0.transactions }
        currentIncomeTotal = allTransactions.filter { $0.direction == "income" }
            .reduce(.zero) { $0 + $1.convertedAmountBase }
        currentExpenseTotal = allTransactions.filter { $0.direction == "expense" }
            .reduce(.zero) { $0 + $1.convertedAmountBase }
    }

    private func totalAmount(from start: Date, to end: Date) -> Decimal {
        let allTransactions = sections.flatMap { $0.transactions }
        let filtered = allTransactions.filter { $0.date >= start && $0.date <= end }
        return filtered.reduce(.zero) { partial, transaction in
            partial + transaction.signedBaseAmount
        }
    }
}

enum TransactionDetailAction {
    case none
    case delete
    case update(TransactionEditChange)
}
