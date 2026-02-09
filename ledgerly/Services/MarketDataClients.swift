import Foundation

protocol MarketDataClient {
    func fetchQuotes(for symbols: [String]) async throws -> [PriceService.MarketQuote]
}

struct AlphaVantageClient: MarketDataClient {
    private let apiKey: String
    private let session: URLSession

    init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    func fetchQuotes(for symbols: [String]) async throws -> [PriceService.MarketQuote] {
        var quotes: [PriceService.MarketQuote] = []
        for symbol in symbols { // simple sequential fetch to respect rate limits
            guard let url = URL(string: "https://www.alphavantage.co/query?function=GLOBAL_QUOTE&symbol=\(symbol)&apikey=\(apiKey)") else { continue }
            print("[AlphaVantageClient] Requesting quote for \(symbol.uppercased())")
            let (data, urlResponse) = try await session.data(from: url)
            if let http = urlResponse as? HTTPURLResponse {
                print("[AlphaVantageClient] Status: \(http.statusCode)")
            }
            if let raw = String(data: data, encoding: .utf8) {
                print("[AlphaVantageClient] Raw response for \(symbol): \(raw)")
            }
            let response = try JSONDecoder().decode(GlobalQuoteResponse.self, from: data)
            if let quote = response.quote,
               let price = Decimal(string: quote.price) {
                quotes.append(.init(symbol: symbol.uppercased(), price: price, currencyCode: quote.currency ?? "USD", provider: "AlphaVantage"))
                print("[AlphaVantageClient] Parsed quote for \(symbol.uppercased()): price=\(price) currency=\(quote.currency ?? "USD")")
            }
            try await Task.sleep(nanoseconds: 400_000_000) // ~0.4s pause to avoid hitting limits
        }
        return quotes
    }

    private struct GlobalQuoteResponse: Decodable {
        let quote: GlobalQuote?

        private enum CodingKeys: String, CodingKey {
            case quote = "Global Quote"
        }
    }

    private struct GlobalQuote: Decodable {
        let price: String
        let currency: String?

        private enum CodingKeys: String, CodingKey {
            case price = "05. price"
            case currency = "08. currency"
        }
    }
}

struct CoinGeckoClient: MarketDataClient {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchQuotes(for symbols: [String]) async throws -> [PriceService.MarketQuote] {
        let ids = symbols.map { $0.lowercased() }.joined(separator: ",")
        guard let url = URL(string: "https://api.coingecko.com/api/v3/simple/price?ids=\(ids)&vs_currencies=usd") else { return [] }
        let (data, _) = try await session.data(from: url)
        let decoded = try JSONDecoder().decode([String: [String: Double]].self, from: data)
        return decoded.compactMap { key, value in
            guard let price = value["usd"] else { return nil }
            return PriceService.MarketQuote(symbol: key.uppercased(), price: Decimal(price), currencyCode: "USD", provider: "CoinGecko")
        }
    }
}
