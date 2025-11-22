import CoreData
import Foundation
import Combine

struct NetWorthTotals {
    let totalAssets: Decimal
    let totalLiabilities: Decimal
    let netWorth: Decimal
    let coreNetWorth: Decimal
    let tangibleNetWorth: Decimal
    let volatileAssets: Decimal
    let walletAssets: Decimal
    let manualAssets: Decimal
    let receivables: Decimal
    let stockInvestments: Decimal
    let cryptoInvestments: Decimal

    var totalInvestments: Decimal { stockInvestments + cryptoInvestments }
}

struct CurrencyConverter {
    let baseCurrency: String
    let rates: [String: Decimal]

    func convert(_ amount: Decimal, from currency: String?) -> Decimal {
        guard let code = currency?.uppercased(), !code.isEmpty else { return amount }
        if code == baseCurrency.uppercased() { return amount }
        guard let rate = rates[code] else { return amount }
        return amount * rate
    }
}

final class NetWorthService {
    private let persistence: PersistenceController

    init(persistence: PersistenceController) {
        self.persistence = persistence
    }

    func computeTotals() -> NetWorthTotals {
        let context = persistence.container.viewContext
        let converter = currencyConverter(in: context)
        var totalAssets: Decimal = .zero
        var totalLiabilities: Decimal = .zero
        var walletAssets: Decimal = .zero
        var manualAssets: Decimal = .zero
        var stockInvestments: Decimal = .zero
        var cryptoInvestments: Decimal = .zero
        var receivables: Decimal = .zero
        var coreAssets: Decimal = .zero
        var tangibleAssets: Decimal = .zero
        var volatileAssets: Decimal = .zero

        context.performAndWait {
            walletAssets = sumWalletBalances(in: context, converter: converter)
            manualAssets = sumManualAssets(
                in: context,
                core: &coreAssets,
                tangible: &tangibleAssets,
                volatile: &volatileAssets,
                receivables: &receivables,
                converter: converter
            )
            totalLiabilities += sumManualLiabilities(in: context, converter: converter)
            let investmentBreakdown = sumHoldingsValue(in: context, converter: converter)
            stockInvestments = investmentBreakdown.stocks
            cryptoInvestments = investmentBreakdown.crypto
        }

        totalAssets = walletAssets + manualAssets + stockInvestments + cryptoInvestments

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
            manualAssets: manualAssets,
            receivables: receivables,
            stockInvestments: stockInvestments,
            cryptoInvestments: cryptoInvestments
        )
    }

    func ensureMonthlySnapshot() {
        let context = persistence.newBackgroundContext()
        context.perform {
            let request: NSFetchRequest<NetWorthSnapshot> = NetWorthSnapshot.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(keyPath: \NetWorthSnapshot.timestamp, ascending: false)]
            request.fetchLimit = 1
            let lastSnapshot = try? context.fetch(request).first
            let needsSnapshot: Bool
            if let last = lastSnapshot?.timestamp {
                needsSnapshot = Calendar.current.dateComponents([.month], from: last, to: Date()).month ?? 0 >= 1
            } else {
                needsSnapshot = true
            }

            guard needsSnapshot else { return }
            let totals = self.computeTotals()
            _ = NetWorthSnapshot.create(
                in: context,
                totalAssets: totals.totalAssets,
                totalLiabilities: totals.totalLiabilities,
                coreNetWorth: totals.coreNetWorth,
                tangibleNetWorth: totals.tangibleNetWorth,
                volatileAssets: totals.volatileAssets
            )
            try? context.save()
        }
    }

    private func sumManualAssets(
        in context: NSManagedObjectContext,
        core: inout Decimal,
        tangible: inout Decimal,
        volatile: inout Decimal,
        receivables: inout Decimal,
        converter: CurrencyConverter
    ) -> Decimal {
        let request: NSFetchRequest<ManualAsset> = ManualAsset.fetchRequest()
        guard let assets = try? context.fetch(request) else { return .zero }
        var total: Decimal = .zero
        for asset in assets {
            let value = converter.convert(asset.value as Decimal? ?? .zero, from: asset.currencyCode)
            total += value
            if asset.includeInCore { core += value }
            if asset.includeInTangible { tangible += value }
            if asset.volatility { volatile += value }
            if (asset.type?.lowercased().contains("receiv") ?? false) {
                receivables += value
            }
        }
        return total
    }

    private func sumManualLiabilities(in context: NSManagedObjectContext, converter: CurrencyConverter) -> Decimal {
        let request: NSFetchRequest<ManualLiability> = ManualLiability.fetchRequest()
        guard let liabilities = try? context.fetch(request) else { return .zero }
        return liabilities.reduce(.zero) {
            $0 + converter.convert($1.balance as Decimal? ?? .zero, from: $1.currencyCode)
        }
    }

    private func sumHoldingsValue(in context: NSManagedObjectContext, converter: CurrencyConverter) -> (total: Decimal, stocks: Decimal, crypto: Decimal) {
        let request: NSFetchRequest<HoldingLot> = HoldingLot.fetchRequest()
        guard let holdings = try? context.fetch(request) else { return (.zero, .zero, .zero) }
        var total: Decimal = .zero
        var stocks: Decimal = .zero
        var crypto: Decimal = .zero
        for lot in holdings {
            guard let asset = lot.asset else { continue }
            let quantity = lot.quantity as Decimal? ?? .zero
            let latestPrice = latestSnapshotPrice(for: asset)
            if let price = latestPrice {
                let value = converter.convert(quantity * price, from: asset.currencyCode)
                total += value
                if (asset.assetType ?? "").lowercased().contains("crypto") {
                    crypto += value
                } else {
                    stocks += value
                }
            }
        }
        return (total, stocks, crypto)
    }

    private func sumWalletBalances(in context: NSManagedObjectContext, converter: CurrencyConverter) -> Decimal {
        let request: NSFetchRequest<Wallet> = Wallet.fetchRequest()
        request.predicate = NSPredicate(format: "includeInNetWorth == YES")
        guard let wallets = try? context.fetch(request) else { return .zero }
        return wallets.reduce(.zero) {
            $0 + converter.convert($1.currentBalance as Decimal? ?? .zero, from: $1.baseCurrencyCode)
        }
    }

    private func currencyConverter(in context: NSManagedObjectContext) -> CurrencyConverter {
        var base = Locale.current.currency?.identifier ?? "USD"
        var rates: [String: Decimal] = [:]
        context.performAndWait {
            if let settings = AppSettings.fetchSingleton(in: context) {
                base = settings.baseCurrencyCode ?? base
                rates = ExchangeRateStorage.decode(settings.customExchangeRates)
            }
        }
        return CurrencyConverter(baseCurrency: base, rates: rates)
    }

    private func latestSnapshotPrice(for asset: InvestmentAsset) -> Decimal? {
        guard let snapshots = asset.snapshots as? Set<PriceSnapshot> else { return nil }
        let latest = snapshots.sorted { ($0.timestamp ?? .distantPast) > ($1.timestamp ?? .distantPast) }.first
        return latest?.price as Decimal?
    }
}
