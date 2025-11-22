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

    func refreshPrices(for symbols: [String]) {
        guard !symbols.isEmpty else { return }
        let context = persistence.newBackgroundContext()
        context.perform {
            let request: NSFetchRequest<InvestmentAsset> = InvestmentAsset.fetchRequest()
            request.predicate = NSPredicate(format: "symbol IN[cd] %@", symbols)
            guard let assets = try? context.fetch(request), !assets.isEmpty else { return }
            let descriptors = assets.map { AssetDescriptor(symbol: $0.symbol ?? "", assetType: $0.assetType ?? "stock") }
            Task { await self.fetchRemoteQuotes(for: descriptors) }
            for asset in assets {
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

// MARK: - Manual Investment Price Sync

final class ManualInvestmentPriceService {
    static let shared = ManualInvestmentPriceService()

    private let persistence: PersistenceController
    private let session: URLSession
    private let apiKey: String?

    private init(
        persistence: PersistenceController = .shared,
        session: URLSession = .shared,
        apiKey: String? = ProcessInfo.processInfo.environment["COINGECKO_API_KEY"] ?? "CG-m6kquXyKfv42izVnmswY7AuM"
    ) {
        self.persistence = persistence
        self.session = session
        self.apiKey = apiKey
    }

    func refresh(baseCurrency: String) async {
        let descriptors = fetchInvestmentDescriptors()
        guard !descriptors.isEmpty else { return }
        guard let priceMap = try? await fetchPrices(for: Array(Set(descriptors.map { $0.coinID }))) else { return }
        let context = persistence.newBackgroundContext()
        await context.perform {
            let converter = CurrencyConverter.fromSettings(in: context)
            let targetCurrency = baseCurrency
            for descriptor in descriptors {
                guard let quoteUSD = priceMap[descriptor.coinID.lowercased()],
                      let asset = try? context.existingObject(with: descriptor.objectID) as? ManualAsset else { continue }
                let basePrice = converter.convertToBase(Decimal(quoteUSD), currency: "USD")
                let quantity = descriptor.quantity
                let newValue = basePrice * quantity
                asset.marketPrice = NSDecimalNumber(decimal: basePrice)
                asset.marketPriceCurrencyCode = targetCurrency
                asset.marketPriceUpdatedAt = Date()
                asset.value = NSDecimalNumber(decimal: newValue)
                asset.currencyCode = targetCurrency
            }
            try? context.save()
        }
    }

    private func fetchInvestmentDescriptors() -> [InvestmentDescriptor] {
        let context = persistence.container.viewContext
        var results: [InvestmentDescriptor] = []
        context.performAndWait {
            let request: NSFetchRequest<ManualAsset> = ManualAsset.fetchRequest()
            request.predicate = NSPredicate(format: "type CONTAINS[cd] %@ AND investmentCoinID != nil", "investment")
            guard let assets = try? context.fetch(request) else { return }
            results = assets.compactMap { asset in
                guard let coinID = asset.investmentCoinID,
                      let quantity = asset.investmentQuantity as Decimal? else { return nil }
                return InvestmentDescriptor(objectID: asset.objectID, coinID: coinID, quantity: quantity)
            }
        }
        return results
    }

    private func fetchPrices(for coinIDs: [String]) async throws -> [String: Double] {
        let ids = coinIDs.map { $0.lowercased() }.joined(separator: ",")
        guard !ids.isEmpty else { return [:] }
        var components = URLComponents(string: "https://api.coingecko.com/api/v3/simple/price")!
        components.queryItems = [
            URLQueryItem(name: "ids", value: ids),
            URLQueryItem(name: "vs_currencies", value: "usd")
        ]
        var request = URLRequest(url: components.url!)
        if let apiKey {
            request.addValue(apiKey, forHTTPHeaderField: "x-cg-demo-api-key")
        }
        let (data, _) = try await session.data(for: request)
        let decoded = try JSONDecoder().decode([String: [String: Double]].self, from: data)
        return decoded.reduce(into: [String: Double]()) { partialResult, pair in
            if let usd = pair.value["usd"] {
                partialResult[pair.key] = usd
            }
        }
    }

    private struct InvestmentDescriptor {
        let objectID: NSManagedObjectID
        let coinID: String
        let quantity: Decimal
    }
}
