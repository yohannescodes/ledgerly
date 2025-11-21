import CoreData
import Foundation

/// Local-only price service used while network access is disabled. Generates deterministic prices per asset.
final class PriceService {
    private let persistence: PersistenceController
    private let alphaClient: MarketDataClient?
    private let coinClient: MarketDataClient?

    init(persistence: PersistenceController, alphaClient: MarketDataClient? = nil, coinClient: MarketDataClient? = nil) {
        self.persistence = persistence
        self.alphaClient = alphaClient
        self.coinClient = coinClient
    }

    func refreshPricesIfNeeded() {
        let context = persistence.newBackgroundContext()
        context.perform {
            let request: NSFetchRequest<InvestmentAsset> = InvestmentAsset.fetchRequest()
            guard let assets = try? context.fetch(request) else { return }
            let descriptors = assets.map { AssetDescriptor(symbol: $0.symbol ?? "", assetType: $0.assetType ?? "stock") }
            Task { await self.fetchRemoteQuotes(for: descriptors) }
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

    private func fetchRemoteQuotes(for descriptors: [AssetDescriptor]) async {
        var quotes: [MarketQuote] = []
        let stockSymbols = descriptors.filter { $0.assetType != "crypto" }.map { $0.symbol }
        let cryptoSymbols = descriptors.filter { $0.assetType == "crypto" }.map { $0.symbol }

        if let alphaClient, !stockSymbols.isEmpty {
            if let fetched = try? await alphaClient.fetchQuotes(for: Array(stockSymbols.prefix(5))) {
                quotes.append(contentsOf: fetched)
            }
        }

        if let coinClient, !cryptoSymbols.isEmpty {
            if let fetched = try? await coinClient.fetchQuotes(for: cryptoSymbols) {
                quotes.append(contentsOf: fetched)
            }
        }

        guard !quotes.isEmpty else { return }
        applyRemoteQuotes(quotes)
    }

    private struct AssetDescriptor {
        let symbol: String
        let assetType: String
    }
}
