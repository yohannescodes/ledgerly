import Foundation

struct MassiveClient {
    struct Quote: Decodable {
        let price: Double
        let currency: String?
    }

    struct TickerSearchResult: Decodable, Identifiable {
        let ticker: String
        let name: String?
        let primaryExchange: String?
        let locale: String?
        let currencyName: String?

        var id: String { ticker }

        var exchangeDisplay: String? {
            let parts = [primaryExchange, locale?.uppercased()].compactMap { $0 }
            return parts.isEmpty ? nil : parts.joined(separator: " • ")
        }

        private enum CodingKeys: String, CodingKey {
            case ticker
            case name
            case primaryExchange = "primary_exchange"
            case locale
            case currencyName = "currency_name"
        }
    }

    private let session: URLSession
    private let apiKey: String?

    init(session: URLSession = .shared, apiKey: String? = ProcessInfo.processInfo.environment["MASSIVE_API_KEY"]) {
        self.session = session
        self.apiKey = apiKey
    }

    func fetchQuote(for ticker: String, vsCurrency: String) async throws -> PriceService.MarketQuote? {
        guard let apiKey else { return nil }
        var components = URLComponents(string: "https://api.massive.com/v3/reference/dividends")!
        components.queryItems = [URLQueryItem(name: "ticker", value: ticker.uppercased())]
        var request = URLRequest(url: components.url!)
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        print("[MassiveClient] Request: \(request.url?.absoluteString ?? "")")
        let (data, urlResponse) = try await session.data(for: request)
        if let http = urlResponse as? HTTPURLResponse {
            print("[MassiveClient] Status: \(http.statusCode)")
        }
        print("[MassiveClient] Response bytes: \(data.count)")
        let decoded = try JSONDecoder().decode(DividendResponse.self, from: data)
        guard let first = decoded.results.first else { return nil }
        return PriceService.MarketQuote(symbol: first.ticker.uppercased(), price: Decimal(first.cash_amount), currencyCode: vsCurrency.uppercased(), provider: "Massive")
    }

    func searchTickers(matching query: String, limit: Int = 8) async throws -> [TickerSearchResult] {
        guard let apiKey, !query.isEmpty else { return [] }
        var components = URLComponents(string: "https://api.massive.com/v3/reference/tickers")!
        components.queryItems = [
            URLQueryItem(name: "search", value: query),
            URLQueryItem(name: "active", value: "true"),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        var request = URLRequest(url: components.url!)
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        print("[MassiveClient] Search request: \(request.url?.absoluteString ?? "")")
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse {
            print("[MassiveClient] Search status: \(http.statusCode)")
        }
        let decoded = try JSONDecoder().decode(TickerSearchResponse.self, from: data)
        return decoded.results
    }

    private struct DividendResponse: Decodable {
        let results: [Dividend]
    }

    private struct Dividend: Decodable {
        let cash_amount: Double
        let ticker: String
    }

    private struct TickerSearchResponse: Decodable {
        let results: [TickerSearchResult]
    }
}
