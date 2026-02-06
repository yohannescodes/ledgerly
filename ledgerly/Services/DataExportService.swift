import CoreData
import Foundation

enum CSVExportKind: CaseIterable, Identifiable {
    case wallets
    case transactions
    case budgets
    case netWorth

    var id: String { rawValue }

    var rawValue: String {
        switch self {
        case .wallets: return "wallets"
        case .transactions: return "transactions"
        case .budgets: return "budgets"
        case .netWorth: return "net_worth_snapshots"
        }
    }

    var fileName: String { rawValue + ".csv" }

    var title: String {
        switch self {
        case .wallets: return "Wallets"
        case .transactions: return "Transactions"
        case .budgets: return "Budgets"
        case .netWorth: return "Net Worth"
        }
    }
}

final class DataExportService {
    private let persistence: PersistenceController
    private let iso8601Formatter: ISO8601DateFormatter

    init(persistence: PersistenceController) {
        self.persistence = persistence
        self.iso8601Formatter = ISO8601DateFormatter()
    }

    func export(kind: CSVExportKind) throws -> URL {
        var rows: [[String]] = []
        var fetchError: Error?
        let context = persistence.container.viewContext
        context.performAndWait {
            do {
                rows = try self.rows(for: kind, in: context)
            } catch {
                fetchError = error
            }
        }
        if let fetchError { throw fetchError }
        return try write(rows: rows, fileName: kind.fileName)
    }

    private func rows(for kind: CSVExportKind, in context: NSManagedObjectContext) throws -> [[String]] {
        switch kind {
        case .wallets:
            let request: NSFetchRequest<Wallet> = Wallet.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(keyPath: \Wallet.sortOrder, ascending: true)]
            let wallets = try context.fetch(request)
            var rows: [[String]] = [["identifier", "name", "type", "currency", "current_balance", "starting_balance", "include_in_networth", "archived"]]
            for wallet in wallets {
                rows.append([
                    wallet.identifier ?? "",
                    wallet.name ?? "",
                    wallet.walletType ?? "",
                    wallet.baseCurrencyCode ?? "",
                    decimalString(wallet.currentBalance as Decimal?),
                    decimalString(wallet.startingBalance as Decimal?),
                    wallet.includeInNetWorth ? "true" : "false",
                    wallet.archived ? "true" : "false"
                ])
            }
            return rows
        case .transactions:
            let request: NSFetchRequest<Transaction> = Transaction.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(keyPath: \Transaction.date, ascending: false)]
            let transactions = try context.fetch(request)
            var rows: [[String]] = [[
                "identifier",
                "direction",
                "amount",
                "currency",
                "base_amount",
                "date",
                "wallet",
                "category",
                "notes"
            ]]
            for txn in transactions {
                rows.append([
                    txn.identifier ?? "",
                    txn.direction ?? "",
                    decimalString(txn.amount as Decimal?),
                    txn.currencyCode ?? "",
                    decimalString(txn.convertedAmountBase as Decimal?),
                    dateString(txn.date),
                    txn.wallet?.name ?? "",
                    txn.category?.name ?? "",
                    txn.notes ?? ""
                ])
            }
            return rows
        case .budgets:
            let request: NSFetchRequest<MonthlyBudget> = MonthlyBudget.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(keyPath: \MonthlyBudget.year, ascending: false), NSSortDescriptor(keyPath: \MonthlyBudget.month, ascending: false)]
            let budgets = try context.fetch(request)
            var rows: [[String]] = [[
                "identifier",
                "category",
                "month",
                "year",
                "limit_amount",
                "currency",
                "auto_reset",
                "carry_over",
                "alert_50_sent",
                "alert_80_sent",
                "alert_100_sent"
            ]]
            for budget in budgets {
                rows.append([
                    budget.identifier ?? "",
                    budget.category?.name ?? "",
                    String(budget.month),
                    String(budget.year),
                    decimalString(budget.limitAmount as Decimal?),
                    budget.currencyCode ?? "",
                    budget.autoReset ? "true" : "false",
                    decimalString(budget.carryOverAmount as Decimal?),
                    budget.alert50Sent ? "true" : "false",
                    budget.alert80Sent ? "true" : "false",
                    budget.alert100Sent ? "true" : "false"
                ])
            }
            return rows
        case .netWorth:
            let request: NSFetchRequest<NetWorthSnapshot> = NetWorthSnapshot.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(keyPath: \NetWorthSnapshot.timestamp, ascending: true)]
            let snapshots = try context.fetch(request)
            var rows: [[String]] = [[
                "identifier",
                "timestamp",
                "currency_code",
                "total_assets",
                "total_liabilities",
                "core_net_worth",
                "tangible_net_worth",
                "volatile_assets",
                "notes"
            ]]
            for snapshot in snapshots {
                rows.append([
                    snapshot.identifier ?? "",
                    dateString(snapshot.timestamp),
                    snapshot.currencyCode ?? "",
                    decimalString(snapshot.totalAssets as Decimal?),
                    decimalString(snapshot.totalLiabilities as Decimal?),
                    decimalString(snapshot.coreNetWorth as Decimal?),
                    decimalString(snapshot.tangibleNetWorth as Decimal?),
                    decimalString(snapshot.volatileAssets as Decimal?),
                    snapshot.notes ?? ""
                ])
            }
            return rows
        }
    }

    private func write(rows: [[String]], fileName: String) throws -> URL {
        let csv = rows.map { row in
            row.map { escape($0) }.joined(separator: ",")
        }.joined(separator: "\n")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("ledgerly_\(fileName)")
        guard let data = csv.data(using: .utf8) else {
            throw DataBackupError.buildFailure
        }
        try data.write(to: url, options: .atomic)
        return url
    }

    private func escape(_ value: String) -> String {
        var clean = value.replacingOccurrences(of: "\r", with: " ").replacingOccurrences(of: "\n", with: " ")
        if clean.contains(",") || clean.contains("\"") {
            clean = "\"" + clean.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return clean
    }

    private func decimalString(_ value: Decimal?) -> String {
        guard let value else { return "" }
        return NSDecimalNumber(decimal: value).stringValue
    }

    private func dateString(_ date: Date?) -> String {
        guard let date else { return "" }
        return iso8601Formatter.string(from: date)
    }
}
