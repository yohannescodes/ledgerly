import CoreData
import Foundation

/// Local-only price service used while network access is disabled. Generates deterministic prices per asset.
final class PriceService {
    private let persistence: PersistenceController

    init(persistence: PersistenceController) {
        self.persistence = persistence
    }

    func refreshPricesIfNeeded() {
        let context = persistence.newBackgroundContext()
        context.perform {
            let request: NSFetchRequest<InvestmentAsset> = InvestmentAsset.fetchRequest()
            guard let assets = try? context.fetch(request) else { return }
            for asset in assets {
                guard self.shouldUpdate(asset: asset) else { continue }
                let newPrice = self.pseudoPrice(for: asset)
                _ = PriceSnapshot.record(
                    in: context,
                    asset: asset,
                    price: newPrice,
                    currencyCode: asset.currencyCode ?? "USD",
                    provider: "local"
                )
            }
            try? context.save()
        }
    }

    private func shouldUpdate(asset: InvestmentAsset) -> Bool {
        guard let snapshots = asset.snapshots as? Set<PriceSnapshot>,
              let latest = snapshots.sorted(by: { ($0.timestamp ?? .distantPast) > ($1.timestamp ?? .distantPast) }).first,
              let timestamp = latest.timestamp else { return true }
        return Date().timeIntervalSince(timestamp) > 3600
    }

    private func pseudoPrice(for asset: InvestmentAsset) -> Decimal {
        let base = Double(abs(asset.symbol.hashValue % 100) + 50)
        let jitter = Double.random(in: -5...5)
        return Decimal(base + jitter)
    }

    struct MarketQuote {
        let symbol: String
        let price: Decimal
        let currencyCode: String
        let provider: String
    }

    /// Entry point for real API integrations. Call with fetched quotes to update Core Data snapshots.
    func applyRemoteQuotes(_ quotes: [MarketQuote]) {
        let context = persistence.newBackgroundContext()
        context.perform {
            for quote in quotes {
                let request: NSFetchRequest<InvestmentAsset> = InvestmentAsset.fetchRequest()
                request.fetchLimit = 1
                request.predicate = NSPredicate(format: "symbol ==[c] %@", quote.symbol)
                guard let asset = try? context.fetch(request).first else { continue }
                _ = PriceSnapshot.record(
                    in: context,
                    asset: asset,
                    price: quote.price,
                    currencyCode: quote.currencyCode,
                    provider: quote.provider
                )
            }
            try? context.save()
        }
    }
}
