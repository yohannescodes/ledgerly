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
    var walletID: NSManagedObjectID?
    var startDate: Date?
    var endDate: Date?
    var searchText: String = ""
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

    struct ExpenseBreakdownEntry: Identifiable {
        let id = UUID()
        let label: String
        let amount: Decimal
        let convertedAmount: Decimal
        let colorHex: String?
    }

    struct ExpenseTotals {
        let currentTotal: Decimal
        let previousTotal: Decimal
    }

    struct IncomeProgressEntry: Identifiable {
        let id = UUID()
        let monthStart: Date
        let amount: Decimal
    }

    func createTransaction(input: TransactionFormInput) {
        let context = persistence.newBackgroundContext()
        context.perform {
            guard let walletID = input.walletID,
                  let wallet = try? context.existingObject(with: walletID) as? Wallet else { return }
            let converter = CurrencyConverter.fromSettings(in: context)
            let baseAmount = converter.convertToBase(input.amount, currency: input.currencyCode)
            let category = input.categoryID.flatMap { try? context.existingObject(with: $0) as? Category }
            _ = Transaction.create(
                in: context,
                direction: input.direction.rawValue,
                amount: input.amount,
                currencyCode: input.currencyCode,
                convertedAmountBase: baseAmount,
                date: input.date,
                wallet: wallet,
                category: category
            )
            self.adjust(wallet: wallet, by: input.amount, currency: input.currencyCode, direction: input.direction, converter: converter)

            if input.direction == .transfer,
               let destinationID = input.destinationWalletID,
               let destination = try? context.existingObject(with: destinationID) as? Wallet {
                self.adjustTransfer(to: destination, amount: input.amount, currency: input.currencyCode, converter: converter)
            }

            do {
                try context.save()
            } catch {
                assertionFailure("Failed to save transaction: \(error)")
            }

            Task { @MainActor in
                NotificationCenter.default.post(name: .walletsDidChange, object: nil)
            }
        }
    }

    func deleteTransaction(id: NSManagedObjectID) {
        let context = persistence.newBackgroundContext()
        context.perform {
            guard let transaction = try? context.existingObject(with: id) as? Transaction else { return }
            context.delete(transaction)
            try? context.save()
            Task { @MainActor in
                NotificationCenter.default.post(name: .walletsDidChange, object: nil)
            }
        }
    }

    func fetchSections(filter: TransactionFilter) -> [TransactionSection] {
        let context = persistence.container.viewContext
        var sections: [TransactionSection] = []
        context.performAndWait {
            let request = Transaction.fetchRequestAll()
            request.predicate = buildPredicate(from: filter, in: context)
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

    func fetchExpenseBreakdown(since startDate: Date) -> [ExpenseBreakdownEntry] {
        let context = persistence.container.viewContext
        var entries: [ExpenseBreakdownEntry] = []
        context.performAndWait {
            let request = Transaction.fetchRequestAll()
            let predicates: [NSPredicate] = [
                NSPredicate(format: "direction == %@", "expense"),
                NSPredicate(format: "date >= %@", startDate as NSDate)
            ]
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
            do {
                let results = try context.fetch(request)
                let models = results.map(TransactionModel.init)
                let grouped = Dictionary(grouping: models) { model -> String in
                    model.category?.name ?? "Uncategorized"
                }
                entries = grouped.map { key, transactions in
                    let total = transactions.reduce(Decimal.zero) { $0 + $1.amount }
                    let convertedTotal = transactions.reduce(Decimal.zero) { $0 + $1.convertedAmountBase }
                    let colorHex = transactions.first?.category?.colorHex
                    return ExpenseBreakdownEntry(label: key, amount: total, convertedAmount: convertedTotal, colorHex: colorHex)
                }
                .sorted { $0.convertedAmount > $1.convertedAmount }
            } catch {
                assertionFailure("Failed to fetch expense breakdown: \(error)")
            }
        }
        return entries
    }

    func fetchMonthlyExpenseTotals() -> ExpenseTotals {
        let context = persistence.container.viewContext
        var current: Decimal = .zero
        var previous: Decimal = .zero
        context.performAndWait {
            let calendar = Calendar.current
            let now = Date()
            let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
            let previousStart = calendar.date(byAdding: .month, value: -1, to: startOfMonth) ?? now
            current = totalExpenses(from: startOfMonth, to: now, context: context)
            previous = totalExpenses(from: previousStart, to: startOfMonth, context: context)
        }
        return ExpenseTotals(currentTotal: current, previousTotal: previous)
    }

    private func totalExpenses(from start: Date, to end: Date, context: NSManagedObjectContext) -> Decimal {
        let request = Transaction.fetchRequestAll()
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "direction == %@", "expense"),
            NSPredicate(format: "date >= %@", start as NSDate),
            NSPredicate(format: "date < %@", end as NSDate)
        ])
        do {
            let results = try context.fetch(request)
            let models = results.map(TransactionModel.init)
            return models.reduce(.zero) { $0 + $1.convertedAmountBase }
        } catch {
            assertionFailure("Failed to fetch expense totals: \(error)")
            return .zero
        }
    }

    func fetchMonthlyIncomeProgress(monthCount: Int = 12) -> [IncomeProgressEntry] {
        let context = persistence.container.viewContext
        var buckets: [Date: Decimal] = [:]
        context.performAndWait {
            let calendar = Calendar.current
            let now = Date()
            guard let windowStart = calendar.date(byAdding: .month, value: -(monthCount - 1), to: startOfMonth(for: now)) else { return }
            let request = Transaction.fetchRequestAll()
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                NSPredicate(format: "direction == %@", "income"),
                NSPredicate(format: "date >= %@", windowStart as NSDate)
            ])
            do {
                let results = try context.fetch(request)
                let models = results.map(TransactionModel.init)
                for model in models {
                    let bucketDate = startOfMonth(for: model.date)
                    buckets[bucketDate, default: .zero] += model.convertedAmountBase
                }
            } catch {
                assertionFailure("Failed to fetch income progress: \(error)")
            }
        }

        let calendar = Calendar.current
        let start = startOfMonth(for: Date())
        return (0..<monthCount).compactMap { offset in
            guard let month = calendar.date(byAdding: .month, value: -(monthCount - 1 - offset), to: start) else { return nil }
            let normalizedMonth = startOfMonth(for: month)
            let amount = buckets[normalizedMonth] ?? .zero
            return IncomeProgressEntry(monthStart: normalizedMonth, amount: amount)
        }
    }

    private func startOfMonth(for date: Date) -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? date
    }

    private static func groupTransactions(_ transactions: [TransactionModel]) -> [TransactionSection] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: transactions) { transaction in
            calendar.startOfDay(for: transaction.date)
        }
        return grouped
            .map { key, values in
                let total = values.reduce(Decimal.zero) { partialResult, transaction in
                    partialResult + transaction.signedBaseAmount
                }
                return TransactionSection(id: key, date: key, transactions: values, total: total)
            }
            .sorted { $0.date > $1.date }
    }

    private func buildPredicate(from filter: TransactionFilter, in context: NSManagedObjectContext) -> NSPredicate? {
        var predicates: [NSPredicate] = []
        if let segmentPredicate = filter.segment.predicate {
            predicates.append(segmentPredicate)
        }
        if let walletID = filter.walletID,
           let wallet = try? context.existingObject(with: walletID) {
            predicates.append(NSPredicate(format: "wallet == %@", wallet))
        }
        if let start = filter.startDate {
            predicates.append(NSPredicate(format: "date >= %@", start as NSDate))
        }
        if let end = filter.endDate {
            predicates.append(NSPredicate(format: "date <= %@", end as NSDate))
        }
        if !filter.searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            let text = filter.searchText
            predicates.append(NSPredicate(format: "notes CONTAINS[cd] %@ OR wallet.name CONTAINS[cd] %@", text, text))
        }
        guard !predicates.isEmpty else { return nil }
        if predicates.count == 1 { return predicates.first }
        return NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
    }

    private func adjust(wallet: Wallet, by amount: Decimal, currency: String, direction: TransactionFormInput.Direction, converter: CurrencyConverter) {
        let baseAmount = converter.convertToBase(amount, currency: currency)
        let walletCurrency = wallet.baseCurrencyCode ?? converter.baseCurrency
        let walletAmount = converter.convertFromBase(baseAmount, to: walletCurrency)
        let current = wallet.currentBalance as Decimal? ?? .zero
        switch direction {
        case .expense:
            wallet.currentBalance = NSDecimalNumber(decimal: current - walletAmount)
        case .income:
            wallet.currentBalance = NSDecimalNumber(decimal: current + walletAmount)
        case .transfer:
            wallet.currentBalance = NSDecimalNumber(decimal: current - walletAmount)
        }
        wallet.updatedAt = Date()
    }

    private func adjustTransfer(to wallet: Wallet, amount: Decimal, currency: String, converter: CurrencyConverter) {
        let baseAmount = converter.convertToBase(amount, currency: currency)
        let walletCurrency = wallet.baseCurrencyCode ?? converter.baseCurrency
        let walletAmount = converter.convertFromBase(baseAmount, to: walletCurrency)
        let current = wallet.currentBalance as Decimal? ?? .zero
        wallet.currentBalance = NSDecimalNumber(decimal: current + walletAmount)
        wallet.updatedAt = Date()
    }
}
