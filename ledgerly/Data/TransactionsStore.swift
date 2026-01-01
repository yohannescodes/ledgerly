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
            let destinationWallet: Wallet?
            if input.direction == .transfer,
               let destinationID = input.destinationWalletID,
               let destination = try? context.existingObject(with: destinationID) as? Wallet {
                destinationWallet = destination
            } else {
                destinationWallet = nil
            }
            _ = Transaction.create(
                in: context,
                direction: input.direction.rawValue,
                amount: input.amount,
                currencyCode: input.currencyCode,
                convertedAmountBase: baseAmount,
                date: input.date,
                wallet: wallet,
                category: category,
                counterpartyWallet: destinationWallet
            )
            self.adjust(wallet: wallet, by: input.amount, currency: input.currencyCode, direction: input.direction, converter: converter)

            if let destinationWallet {
                self.adjustTransfer(to: destinationWallet, amount: input.amount, currency: input.currencyCode, converter: converter)
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
            let converter = CurrencyConverter.fromSettings(in: context)
            let state = TransactionBalanceState(transaction: transaction, converter: converter)
            self.applyWalletAdjustments(for: state, converter: converter, multiplier: Decimal(-1))
            context.delete(transaction)
            try? context.save()
            Task { @MainActor in
                NotificationCenter.default.post(name: .walletsDidChange, object: nil)
            }
        }
    }

    func updateTransaction(id: NSManagedObjectID, change: TransactionEditChange) -> TransactionModel? {
        let context = persistence.newBackgroundContext()
        var updatedModel: TransactionModel?
        context.performAndWait {
            guard let transaction = try? context.existingObject(with: id) as? Transaction else { return }
            let converter = CurrencyConverter.fromSettings(in: context)
            let previousState = TransactionBalanceState(transaction: transaction, converter: converter)
            apply(change: change, to: transaction, converter: converter, context: context)
            if changeAffectsWalletBalance(change) {
                applyBalanceAdjustments(previousState: previousState, transaction: transaction, converter: converter)
            }
            transaction.updatedAt = Date()
            do {
                try context.save()
                updatedModel = TransactionModel(managedObject: transaction)
            } catch {
                context.rollback()
                assertionFailure("Failed to update transaction: \(error)")
            }
        }
        if updatedModel != nil {
            Task { @MainActor in
                NotificationCenter.default.post(name: .walletsDidChange, object: nil)
            }
        }
        return updatedModel
    }

    private func apply(change: TransactionEditChange, to transaction: Transaction, converter: CurrencyConverter, context: NSManagedObjectContext) {
        switch change {
        case .direction(let direction):
            transaction.direction = direction.rawValue
            transaction.isTransfer = (direction == .transfer)
            if direction != .transfer {
                transaction.counterpartyWallet = nil
            }
        case .amount(let amount):
            transaction.amount = NSDecimalNumber(decimal: amount)
            let base = converter.convertToBase(amount, currency: transaction.currencyCode)
            transaction.convertedAmountBase = NSDecimalNumber(decimal: base)
        case .currency(let code):
            transaction.currencyCode = code
            let amount = transaction.amount as Decimal? ?? .zero
            let base = converter.convertToBase(amount, currency: code)
            transaction.convertedAmountBase = NSDecimalNumber(decimal: base)
        case .wallet(let walletID):
            if let wallet = try? context.existingObject(with: walletID) as? Wallet {
                transaction.wallet = wallet
            }
        case .date(let date):
            transaction.date = date
        case .notes(let notes):
            let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
            transaction.notes = trimmed.isEmpty ? nil : trimmed
        case .category(let categoryID):
            if let categoryID,
               let category = try? context.existingObject(with: categoryID) as? Category {
                transaction.category = category
            } else {
                transaction.category = nil
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
        let converter = CurrencyConverter.fromSettings(in: context)
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
                    let convertedTotal = transactions.reduce(Decimal.zero) { partial, model in
                        partial + converter.convertToBase(model.amount, currency: model.currencyCode)
                    }
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
        let converter = CurrencyConverter.fromSettings(in: context)
        var current: Decimal = .zero
        var previous: Decimal = .zero
        context.performAndWait {
            let calendar = Calendar.current
            let now = Date()
            let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
            let previousStart = calendar.date(byAdding: .month, value: -1, to: startOfMonth) ?? now
            current = totalExpenses(from: startOfMonth, to: now, context: context, converter: converter)
            previous = totalExpenses(from: previousStart, to: startOfMonth, context: context, converter: converter)
        }
        return ExpenseTotals(currentTotal: current, previousTotal: previous)
    }

    private func totalExpenses(from start: Date, to end: Date, context: NSManagedObjectContext, converter: CurrencyConverter) -> Decimal {
        let request = Transaction.fetchRequestAll()
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "direction == %@", "expense"),
            NSPredicate(format: "date >= %@", start as NSDate),
            NSPredicate(format: "date < %@", end as NSDate)
        ])
        do {
            let results = try context.fetch(request)
            let models = results.map(TransactionModel.init)
            return models.reduce(.zero) { partial, model in
                partial + converter.convertToBase(model.amount, currency: model.currencyCode)
            }
        } catch {
            assertionFailure("Failed to fetch expense totals: \(error)")
            return .zero
        }
    }

    func fetchIncomeProgress(forYear year: Int = Calendar.current.component(.year, from: Date())) -> (entries: [IncomeProgressEntry], hasEarlierData: Bool) {
        let context = persistence.container.viewContext
        let converter = CurrencyConverter.fromSettings(in: context)
        var buckets: [Int: Decimal] = [:]
        var hasEarlierMonths = false
        context.performAndWait {
            let calendar = Calendar.current
            guard
                let windowStart = calendar.date(from: DateComponents(year: year, month: 1, day: 1)),
                let windowEnd = calendar.date(from: DateComponents(year: year + 1, month: 1, day: 1))
            else { return }
            let request = Transaction.fetchRequestAll()
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                NSPredicate(format: "direction == %@", "income"),
                NSPredicate(format: "date >= %@", windowStart as NSDate),
                NSPredicate(format: "date < %@", windowEnd as NSDate)
            ])
            do {
                let results = try context.fetch(request)
                let models = results.map(TransactionModel.init)
                for model in models {
                    let month = calendar.component(.month, from: model.date)
                    let baseAmount = converter.convertToBase(model.amount, currency: model.currencyCode)
                    buckets[month, default: .zero] += baseAmount
                }
                let earlierRequest = Transaction.fetchRequestAll(limit: 1)
                earlierRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                    NSPredicate(format: "direction == %@", "income"),
                    NSPredicate(format: "date < %@", windowStart as NSDate)
                ])
                if let results = try? context.fetch(earlierRequest) {
                    hasEarlierMonths = !results.isEmpty
                }
            } catch {
                assertionFailure("Failed to fetch income progress: \(error)")
            }
        }

        let calendar = Calendar.current
        let entries: [IncomeProgressEntry] = (1...12).compactMap { month in
            guard let date = calendar.date(from: DateComponents(year: year, month: month, day: 1)) else { return nil }
            let amount = buckets[month] ?? .zero
            return IncomeProgressEntry(monthStart: date, amount: amount)
        }
        return (entries, hasEarlierMonths)
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
        let delta = walletDelta(amount: amount, currency: currency, direction: direction, wallet: wallet, converter: converter)
        applyWalletDelta(delta, to: wallet)
    }

    private func adjustTransfer(to wallet: Wallet, amount: Decimal, currency: String, converter: CurrencyConverter) {
        let delta = walletDelta(amount: amount, currency: currency, direction: .income, wallet: wallet, converter: converter)
        applyWalletDelta(delta, to: wallet)
    }

    private func applyBalanceAdjustments(previousState: TransactionBalanceState, transaction: Transaction, converter: CurrencyConverter) {
        applyWalletAdjustments(for: previousState, converter: converter, multiplier: Decimal(-1))
        let newState = TransactionBalanceState(transaction: transaction, converter: converter)
        applyWalletAdjustments(for: newState, converter: converter, multiplier: Decimal(1))
    }

    private func applyWalletAdjustments(for state: TransactionBalanceState, converter: CurrencyConverter, multiplier: Decimal) {
        if let wallet = state.wallet {
            let delta = walletDelta(
                amount: state.amount,
                currency: state.currencyCode,
                direction: state.direction,
                wallet: wallet,
                converter: converter
            ) * multiplier
            applyWalletDelta(delta, to: wallet)
        }
        if state.isTransfer, let counterparty = state.counterpartyWallet {
            let counterpartyDelta = walletDelta(
                amount: state.amount,
                currency: state.currencyCode,
                direction: .income,
                wallet: counterparty,
                converter: converter
            ) * multiplier
            applyWalletDelta(counterpartyDelta, to: counterparty)
        }
    }

    private func walletDelta(amount: Decimal, currency: String, direction: TransactionFormInput.Direction, wallet: Wallet, converter: CurrencyConverter) -> Decimal {
        let baseAmount = converter.convertToBase(amount, currency: currency)
        let walletCurrency = wallet.baseCurrencyCode ?? converter.baseCurrency
        let walletAmount = converter.convertFromBase(baseAmount, to: walletCurrency)
        switch direction {
        case .expense, .transfer:
            return -walletAmount
        case .income:
            return walletAmount
        }
    }

    private func applyWalletDelta(_ delta: Decimal, to wallet: Wallet) {
        let current = wallet.currentBalance as Decimal? ?? .zero
        wallet.currentBalance = NSDecimalNumber(decimal: current + delta)
        wallet.updatedAt = Date()
    }

    private func changeAffectsWalletBalance(_ change: TransactionEditChange) -> Bool {
        switch change {
        case .direction, .amount, .currency, .wallet:
            return true
        case .date, .notes, .category:
            return false
        }
    }

    private struct TransactionBalanceState {
        let wallet: Wallet?
        let counterpartyWallet: Wallet?
        let direction: TransactionFormInput.Direction
        let amount: Decimal
        let currencyCode: String

        var isTransfer: Bool { direction == .transfer }

        init(transaction: Transaction, converter: CurrencyConverter) {
            wallet = transaction.wallet
            counterpartyWallet = transaction.counterpartyWallet
            if let rawDirection = transaction.direction,
               let parsed = TransactionFormInput.Direction(rawValue: rawDirection) {
                direction = parsed
            } else {
                direction = .expense
            }
            amount = transaction.amount as Decimal? ?? .zero
            currencyCode = transaction.currencyCode ?? converter.baseCurrency
        }
    }
}
