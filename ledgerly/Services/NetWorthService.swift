import CoreData
import Foundation
import Combine

struct NetWorthTotals {
    let totalAssets: Decimal
    let totalLiabilities: Decimal
    let coreNetWorth: Decimal
    let tangibleNetWorth: Decimal
    let volatileAssets: Decimal
}

final class NetWorthService {
    private let persistence: PersistenceController

    init(persistence: PersistenceController) {
        self.persistence = persistence
    }

    func computeTotals() -> NetWorthTotals {
        let context = persistence.container.viewContext
        var totalAssets: Decimal = .zero
        var totalLiabilities: Decimal = .zero
        var coreAssets: Decimal = .zero
        var tangibleAssets: Decimal = .zero
        var volatileAssets: Decimal = .zero

        context.performAndWait {
            totalAssets += sumWalletBalances(in: context)
            totalAssets += sumManualAssets(in: context, core: &coreAssets, tangible: &tangibleAssets, volatile: &volatileAssets)
            totalLiabilities += sumManualLiabilities(in: context)
            totalAssets += sumHoldingsValue(in: context)
        }

        let coreNetWorth = coreAssets - totalLiabilities
        let tangibleNetWorth = tangibleAssets - totalLiabilities
        return NetWorthTotals(
            totalAssets: totalAssets,
            totalLiabilities: totalLiabilities,
            coreNetWorth: coreNetWorth,
            tangibleNetWorth: tangibleNetWorth,
            volatileAssets: volatileAssets
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

    private func sumWalletBalances(in context: NSManagedObjectContext) -> Decimal {
        let request: NSFetchRequest<Wallet> = Wallet.fetchRequest()
        guard let wallets = try? context.fetch(request) else { return .zero }
        return wallets.reduce(.zero) { $0 + ( $1.currentBalance as Decimal? ?? .zero) }
    }

    private func sumManualAssets(
        in context: NSManagedObjectContext,
        core: inout Decimal,
        tangible: inout Decimal,
        volatile: inout Decimal
    ) -> Decimal {
        let request: NSFetchRequest<ManualAsset> = ManualAsset.fetchRequest()
        guard let assets = try? context.fetch(request) else { return .zero }
        var total: Decimal = .zero
        for asset in assets {
            let value = asset.value as Decimal? ?? .zero
            total += value
            if asset.includeInCore { core += value }
            if asset.includeInTangible { tangible += value }
            if asset.volatility { volatile += value }
        }
        return total
    }

    private func sumManualLiabilities(in context: NSManagedObjectContext) -> Decimal {
        let request: NSFetchRequest<ManualLiability> = ManualLiability.fetchRequest()
        guard let liabilities = try? context.fetch(request) else { return .zero }
        return liabilities.reduce(.zero) { $0 + ( $1.balance as Decimal? ?? .zero) }
    }

    private func sumHoldingsValue(in context: NSManagedObjectContext) -> Decimal {
        let request: NSFetchRequest<HoldingLot> = HoldingLot.fetchRequest()
        guard let holdings = try? context.fetch(request) else { return .zero }
        var total: Decimal = .zero
        for lot in holdings {
            guard let asset = lot.asset else { continue }
            let quantity = lot.quantity as Decimal? ?? .zero
            let latestPrice = latestSnapshotPrice(for: asset)
            if let price = latestPrice {
                total += quantity * price
            }
        }
        return total
    }

    private func latestSnapshotPrice(for asset: InvestmentAsset) -> Decimal? {
        guard let snapshots = asset.snapshots as? Set<PriceSnapshot> else { return nil }
        let latest = snapshots.sorted { ($0.timestamp ?? .distantPast) > ($1.timestamp ?? .distantPast) }.first
        return latest?.price as Decimal?
    }
}
