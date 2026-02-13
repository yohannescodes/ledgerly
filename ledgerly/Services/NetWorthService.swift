import CoreData
import Foundation

struct NetWorthTotals {
    let totalAssets: Decimal
    let totalLiabilities: Decimal
    let netWorth: Decimal
    let coreNetWorth: Decimal
    let tangibleNetWorth: Decimal
    let volatileAssets: Decimal
    let walletAssets: Decimal
    let tangibleAssets: Decimal
    let manualInvestments: Decimal
    let receivables: Decimal

    var totalInvestments: Decimal { manualInvestments }
}

struct FxExposureSnapshot {
    let foreignAssets: Decimal
    let foreignLiabilities: Decimal
    let totalAssets: Decimal
    let totalLiabilities: Decimal

    var netExposure: Decimal { foreignAssets - foreignLiabilities }
    var foreignAssetShare: Decimal? { totalAssets == .zero ? nil : (foreignAssets / totalAssets) }
}

struct ManualInvestmentPerformanceSnapshot {
    let totalCost: Decimal
    let totalCurrentValue: Decimal
    let totalProfit: Decimal
    let investmentCount: Int

    var returnPercent: Decimal? { totalCost == .zero ? nil : (totalProfit / totalCost) }
}

final class NetWorthService {
    private let persistence: PersistenceController
    private let snapshotStartComponents = DateComponents(year: 2026, month: 1, day: 1)

    init(persistence: PersistenceController) {
        self.persistence = persistence
    }

    var snapshotStartDate: Date? {
        Calendar.current.date(from: snapshotStartComponents)
    }

    func computeTotals() -> NetWorthTotals {
        let context = persistence.container.viewContext
        let converter = CurrencyConverter.fromSettings(in: context)
        var totalAssets: Decimal = .zero
        var totalLiabilities: Decimal = .zero
        var walletAssets: Decimal = .zero
        var manualAssetsTotal: Decimal = .zero
        var manualInvestments: Decimal = .zero
        var receivables: Decimal = .zero
        var coreAssets: Decimal = .zero
        var tangibleAssets: Decimal = .zero
        var volatileAssets: Decimal = .zero

        context.performAndWait {
            walletAssets = sumWalletBalances(in: context, converter: converter)
            manualAssetsTotal = sumManualAssets(
                in: context,
                core: &coreAssets,
                tangible: &tangibleAssets,
                volatile: &volatileAssets,
                receivables: &receivables,
                manualInvestments: &manualInvestments,
                converter: converter
            )
            totalLiabilities += sumManualLiabilities(in: context, converter: converter)
        }

        let tangibleAssetsNet = max(manualAssetsTotal - manualInvestments - receivables, .zero)
        totalAssets = walletAssets + tangibleAssetsNet + receivables + manualInvestments

        let coreNetWorth = coreAssets - totalLiabilities
        let tangibleNetWorth = tangibleAssets - totalLiabilities
        let netWorth = totalAssets - totalLiabilities
        return NetWorthTotals(
            totalAssets: totalAssets,
            totalLiabilities: totalLiabilities,
            netWorth: netWorth,
            coreNetWorth: coreNetWorth,
            tangibleNetWorth: tangibleNetWorth,
            volatileAssets: volatileAssets,
            walletAssets: walletAssets,
            tangibleAssets: tangibleAssetsNet,
            manualInvestments: manualInvestments,
            receivables: receivables
        )
    }

    func rebuildDailySnapshots() throws -> Int {
        let context = persistence.newBackgroundContext()
        var outcome: Result<Int, Error> = .success(0)
        context.performAndWait {
            do {
                outcome = .success(try rebuildDailySnapshots(in: context))
            } catch {
                outcome = .failure(error)
            }
        }
        return try outcome.get()
    }

    func ensureDailySnapshot() {
        let context = persistence.newBackgroundContext()
        context.perform {
            let calendar = Calendar.current
            guard let snapshotStart = calendar.date(from: self.snapshotStartComponents) else { return }
            let now = Date()
            guard let todayAtFive = calendar.date(
                bySettingHour: 17,
                minute: 0,
                second: 0,
                of: now
            ) else { return }
            let targetDate: Date
            if now >= todayAtFive {
                targetDate = todayAtFive
            } else {
                guard let yesterdayAtFive = calendar.date(byAdding: .day, value: -1, to: todayAtFive) else { return }
                targetDate = yesterdayAtFive
            }
            guard targetDate >= snapshotStart else { return }
            let dayStart = calendar.startOfDay(for: targetDate)
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return }
            let exchangeModeUsed = self.currentExchangeMode(in: context).rawValue
            let request: NSFetchRequest<NetWorthSnapshot> = NetWorthSnapshot.fetchRequest()
            request.predicate = NSPredicate(
                format: "timestamp >= %@ AND timestamp < %@ AND exchangeModeUsed == %@",
                dayStart as NSDate,
                nextDay as NSDate,
                exchangeModeUsed
            )
            request.fetchLimit = 1
            let existing = try? context.fetch(request).first
            guard existing == nil else { return }
            let converter = CurrencyConverter.fromSettings(in: context)
            let totals = self.computeTotals(
                asOf: targetDate,
                in: context,
                converter: converter,
                useCurrentBalances: true
            )
            let snapshot = NetWorthSnapshot.create(
                in: context,
                totalAssets: totals.totalAssets,
                totalLiabilities: totals.totalLiabilities,
                coreNetWorth: totals.coreNetWorth,
                tangibleNetWorth: totals.tangibleNetWorth,
                volatileAssets: totals.volatileAssets,
                currencyCode: converter.baseCurrency,
                exchangeModeUsed: exchangeModeUsed
            )
            snapshot.timestamp = targetDate
            try? context.save()
        }
    }

    func computeFxExposure() -> FxExposureSnapshot {
        let context = persistence.container.viewContext
        let converter = CurrencyConverter.fromSettings(in: context)
        var foreignAssets: Decimal = .zero
        var baseAssets: Decimal = .zero
        var foreignLiabilities: Decimal = .zero
        var baseLiabilities: Decimal = .zero

        context.performAndWait {
            let baseCode = converter.baseCurrency.uppercased()

            let walletRequest: NSFetchRequest<Wallet> = Wallet.fetchRequest()
            walletRequest.predicate = NSPredicate(format: "includeInNetWorth == YES")
            if let wallets = try? context.fetch(walletRequest) {
                for wallet in wallets {
                    let code = (wallet.baseCurrencyCode ?? converter.baseCurrency).uppercased()
                    let balance = wallet.currentBalance as Decimal? ?? .zero
                    let converted = converter.convertToBase(balance, currency: code)
                    if code == baseCode {
                        baseAssets += converted
                    } else {
                        foreignAssets += converted
                    }
                }
            }

            let assetRequest: NSFetchRequest<ManualAsset> = ManualAsset.fetchRequest()
            if let assets = try? context.fetch(assetRequest) {
                for asset in assets {
                    let code = (asset.currencyCode ?? converter.baseCurrency).uppercased()
                    let value = asset.value as Decimal? ?? .zero
                    let converted = converter.convertToBase(value, currency: code)
                    if code == baseCode {
                        baseAssets += converted
                    } else {
                        foreignAssets += converted
                    }
                }
            }

            let liabilityRequest: NSFetchRequest<ManualLiability> = ManualLiability.fetchRequest()
            if let liabilities = try? context.fetch(liabilityRequest) {
                for liability in liabilities {
                    let code = (liability.currencyCode ?? converter.baseCurrency).uppercased()
                    let balance = liability.balance as Decimal? ?? .zero
                    let converted = converter.convertToBase(balance, currency: code)
                    if code == baseCode {
                        baseLiabilities += converted
                    } else {
                        foreignLiabilities += converted
                    }
                }
            }
        }

        return FxExposureSnapshot(
            foreignAssets: foreignAssets,
            foreignLiabilities: foreignLiabilities,
            totalAssets: baseAssets + foreignAssets,
            totalLiabilities: baseLiabilities + foreignLiabilities
        )
    }

    func computeManualInvestmentPerformance() -> ManualInvestmentPerformanceSnapshot? {
        let context = persistence.container.viewContext
        let converter = CurrencyConverter.fromSettings(in: context)
        var totalCost: Decimal = .zero
        var totalCurrentValue: Decimal = .zero
        var count = 0

        context.performAndWait {
            let request: NSFetchRequest<ManualAsset> = ManualAsset.fetchRequest()
            guard let assets = try? context.fetch(request), !assets.isEmpty else { return }
            for asset in assets where isManualInvestment(asset: asset) {
                let quantity = asset.investmentQuantity as Decimal? ?? .zero
                let costPerUnit = asset.investmentCostPerUnit as Decimal? ?? .zero
                let costBasis = quantity * costPerUnit
                let currentValue = (asset.value as Decimal?) ?? costBasis
                let currency = asset.currencyCode ?? converter.baseCurrency
                totalCost += converter.convertToBase(costBasis, currency: currency)
                totalCurrentValue += converter.convertToBase(currentValue, currency: currency)
                count += 1
            }
        }

        guard count > 0 else { return nil }
        let totalProfit = totalCurrentValue - totalCost
        return ManualInvestmentPerformanceSnapshot(
            totalCost: totalCost,
            totalCurrentValue: totalCurrentValue,
            totalProfit: totalProfit,
            investmentCount: count
        )
    }

    private func sumManualAssets(
        in context: NSManagedObjectContext,
        asOf date: Date? = nil,
        core: inout Decimal,
        tangible: inout Decimal,
        volatile: inout Decimal,
        receivables: inout Decimal,
        manualInvestments: inout Decimal,
        converter: CurrencyConverter
    ) -> Decimal {
        let request: NSFetchRequest<ManualAsset> = ManualAsset.fetchRequest()
        guard let assets = try? context.fetch(request) else { return .zero }
        var total: Decimal = .zero
        for asset in assets {
            if let date, let valuationDate = asset.valuationDate, valuationDate > date {
                continue
            }
            let value = converter.convertToBase(asset.value as Decimal? ?? .zero, currency: asset.currencyCode)
            total += value
            if asset.includeInCore { core += value }
            if asset.includeInTangible { tangible += value }
            if asset.volatility { volatile += value }
            if (asset.type?.lowercased().contains("receiv") ?? false) {
                receivables += value
            }
            if isManualInvestment(asset: asset) {
                manualInvestments += value
            }
        }
        return total
    }

    private func sumWalletBalances(
        asOf date: Date,
        in context: NSManagedObjectContext,
        converter: CurrencyConverter
    ) -> Decimal {
        let request: NSFetchRequest<Wallet> = Wallet.fetchRequest()
        request.predicate = NSPredicate(format: "includeInNetWorth == YES")
        guard let wallets = try? context.fetch(request), !wallets.isEmpty else { return .zero }
        var balances: [NSManagedObjectID: Decimal] = [:]
        var currencies: [NSManagedObjectID: String] = [:]
        for wallet in wallets {
            balances[wallet.objectID] = wallet.startingBalance as Decimal? ?? .zero
            currencies[wallet.objectID] = wallet.baseCurrencyCode ?? converter.baseCurrency
        }

        let transactionRequest: NSFetchRequest<Transaction> = Transaction.fetchRequest()
        transactionRequest.predicate = NSPredicate(format: "date <= %@", date as NSDate)
        if let transactions = try? context.fetch(transactionRequest) {
            for transaction in transactions {
                if transaction.affectsBalance == false { continue }
                let amount = transaction.amount as Decimal? ?? .zero
                let baseAmount = converter.convertToBase(amount, currency: transaction.currencyCode)
                if let wallet = transaction.wallet, let currency = currencies[wallet.objectID] {
                    let walletAmount = converter.convertFromBase(baseAmount, to: currency)
                    let direction = (transaction.direction ?? "expense").lowercased()
                    let delta: Decimal
                    switch direction {
                    case "income":
                        delta = walletAmount
                    case "expense", "transfer":
                        delta = -walletAmount
                    default:
                        delta = walletAmount
                    }
                    balances[wallet.objectID, default: .zero] += delta
                }
                if (transaction.direction ?? "").lowercased() == "transfer",
                   let counterparty = transaction.counterpartyWallet,
                   let currency = currencies[counterparty.objectID] {
                    let walletAmount = converter.convertFromBase(baseAmount, to: currency)
                    balances[counterparty.objectID, default: .zero] += walletAmount
                }
            }
        }

        return wallets.reduce(.zero) { partial, wallet in
            let balance = balances[wallet.objectID] ?? .zero
            let currency = currencies[wallet.objectID] ?? converter.baseCurrency
            return partial + converter.convertToBase(balance, currency: currency)
        }
    }

    private func rebuildDailySnapshots(in context: NSManagedObjectContext) throws -> Int {
        let exchangeModeUsed = currentExchangeMode(in: context).rawValue
        let request: NSFetchRequest<NetWorthSnapshot> = NetWorthSnapshot.fetchRequest()
        request.predicate = NSPredicate(format: "exchangeModeUsed == %@", exchangeModeUsed)
        let existing = try context.fetch(request)
        existing.forEach { context.delete($0) }

        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        let baseline = calendar.date(from: snapshotStartComponents) ?? startOfToday
        let startDate = max(startOfToday, baseline)
        guard let todayAtFive = calendar.date(bySettingHour: 17, minute: 0, second: 0, of: now) else {
            try context.save()
            return 0
        }
        let lastSnapshotDate: Date
        if now >= todayAtFive {
            lastSnapshotDate = todayAtFive
        } else {
            guard let yesterdayAtFive = calendar.date(byAdding: .day, value: -1, to: todayAtFive) else {
                try context.save()
                return 0
            }
            lastSnapshotDate = yesterdayAtFive
        }
        guard lastSnapshotDate >= startDate else {
            try context.save()
            return 0
        }
        let converter = CurrencyConverter.fromSettings(in: context)
        var created = 0
        var dayStart = calendar.startOfDay(for: startDate)
        if let firstSnapshotDate = calendar.date(bySettingHour: 17, minute: 0, second: 0, of: dayStart),
           firstSnapshotDate < startDate {
            if let nextDay = calendar.date(byAdding: .day, value: 1, to: dayStart) {
                dayStart = nextDay
            }
        }
        while true {
            guard let snapshotDate = calendar.date(bySettingHour: 17, minute: 0, second: 0, of: dayStart) else { break }
            if snapshotDate > lastSnapshotDate { break }
            let totals = computeTotals(
                asOf: snapshotDate,
                in: context,
                converter: converter,
                useCurrentBalances: true
            )
            let snapshot = NetWorthSnapshot.create(
                in: context,
                totalAssets: totals.totalAssets,
                totalLiabilities: totals.totalLiabilities,
                coreNetWorth: totals.coreNetWorth,
                tangibleNetWorth: totals.tangibleNetWorth,
                volatileAssets: totals.volatileAssets,
                currencyCode: converter.baseCurrency,
                exchangeModeUsed: exchangeModeUsed
            )
            snapshot.timestamp = snapshotDate
            created += 1
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: dayStart) else { break }
            dayStart = nextDay
        }
        try context.save()
        return created
    }

    private func earliestSnapshotDate(in context: NSManagedObjectContext) -> Date? {
        var dates: [Date] = []

        let transactionRequest: NSFetchRequest<Transaction> = Transaction.fetchRequest()
        transactionRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Transaction.date, ascending: true)]
        transactionRequest.fetchLimit = 1
        if let transaction = try? context.fetch(transactionRequest).first, let date = transaction.date {
            dates.append(date)
        }

        let walletRequest: NSFetchRequest<Wallet> = Wallet.fetchRequest()
        walletRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Wallet.createdAt, ascending: true)]
        walletRequest.fetchLimit = 1
        if let wallet = try? context.fetch(walletRequest).first, let date = wallet.createdAt {
            dates.append(date)
        }

        let assetRequest: NSFetchRequest<ManualAsset> = ManualAsset.fetchRequest()
        assetRequest.sortDescriptors = [NSSortDescriptor(keyPath: \ManualAsset.valuationDate, ascending: true)]
        assetRequest.fetchLimit = 1
        if let asset = try? context.fetch(assetRequest).first, let valuationDate = asset.valuationDate {
            dates.append(valuationDate)
        }

        return dates.min()
    }

    private func computeTotals(
        asOf date: Date,
        in context: NSManagedObjectContext,
        converter: CurrencyConverter,
        useCurrentBalances: Bool = false
    ) -> NetWorthTotals {
        var totalAssets: Decimal = .zero
        var totalLiabilities: Decimal = .zero
        var walletAssets: Decimal = .zero
        var manualAssetsTotal: Decimal = .zero
        var manualInvestments: Decimal = .zero
        var receivables: Decimal = .zero
        var coreAssets: Decimal = .zero
        var tangibleAssets: Decimal = .zero
        var volatileAssets: Decimal = .zero

        if useCurrentBalances {
            walletAssets = sumWalletBalances(in: context, converter: converter)
        } else {
            walletAssets = sumWalletBalances(asOf: date, in: context, converter: converter)
        }
        manualAssetsTotal = sumManualAssets(
            in: context,
            asOf: date,
            core: &coreAssets,
            tangible: &tangibleAssets,
            volatile: &volatileAssets,
            receivables: &receivables,
            manualInvestments: &manualInvestments,
            converter: converter
        )
        totalLiabilities += sumManualLiabilities(in: context, converter: converter)

        let tangibleAssetsNet = max(manualAssetsTotal - manualInvestments - receivables, .zero)
        totalAssets = walletAssets + tangibleAssetsNet + receivables + manualInvestments

        let coreNetWorth = coreAssets - totalLiabilities
        let tangibleNetWorth = tangibleAssets - totalLiabilities
        let netWorth = totalAssets - totalLiabilities
        return NetWorthTotals(
            totalAssets: totalAssets,
            totalLiabilities: totalLiabilities,
            netWorth: netWorth,
            coreNetWorth: coreNetWorth,
            tangibleNetWorth: tangibleNetWorth,
            volatileAssets: volatileAssets,
            walletAssets: walletAssets,
            tangibleAssets: tangibleAssetsNet,
            manualInvestments: manualInvestments,
            receivables: receivables
        )
    }

    private func isManualInvestment(asset: ManualAsset) -> Bool {
        if let coinID = asset.investmentCoinID, !coinID.isEmpty { return true }
        if let type = asset.type?.lowercased(), type.contains("investment") { return true }
        return false
    }

    private func sumManualLiabilities(in context: NSManagedObjectContext, converter: CurrencyConverter) -> Decimal {
        let request: NSFetchRequest<ManualLiability> = ManualLiability.fetchRequest()
        guard let liabilities = try? context.fetch(request) else { return .zero }
        return liabilities.reduce(.zero) {
            $0 + converter.convertToBase($1.balance as Decimal? ?? .zero, currency: $1.currencyCode)
        }
    }

    private func sumWalletBalances(in context: NSManagedObjectContext, converter: CurrencyConverter) -> Decimal {
        let request: NSFetchRequest<Wallet> = Wallet.fetchRequest()
        request.predicate = NSPredicate(format: "includeInNetWorth == YES")
        guard let wallets = try? context.fetch(request) else { return .zero }
        return wallets.reduce(.zero) {
            $0 + converter.convertToBase($1.currentBalance as Decimal? ?? .zero, currency: $1.baseCurrencyCode)
        }
    }

    private func currentExchangeMode(in context: NSManagedObjectContext) -> ExchangeMode {
        ExchangeMode(storedValue: AppSettings.fetchSingleton(in: context)?.exchangeMode)
    }
}
