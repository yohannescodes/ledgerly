import Foundation

struct ExchangeRateAPILatestPayload {
    let baseCode: String
    let conversionRates: [String: Decimal]
    let timeLastUpdateUTC: Date?
}

enum ExchangeRateAPIClientError: LocalizedError {
    case invalidURL
    case nonHTTPResponse
    case badStatusCode(Int)
    case unsupportedResult(String)
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Unable to build ExchangeRate-API request URL."
        case .nonHTTPResponse:
            return "ExchangeRate-API returned an invalid response."
        case .badStatusCode(let status):
            return "ExchangeRate-API request failed with status \(status)."
        case .unsupportedResult(let result):
            return "ExchangeRate-API returned an unsupported result: \(result)."
        case .apiError(let details):
            return details
        }
    }
}

struct ExchangeRateAPIClient {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchLatestRates(apiKey: String, baseCurrencyCode: String) async throws -> ExchangeRateAPILatestPayload {
        let normalizedBase = baseCurrencyCode.uppercased()
        let normalizedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            let encodedKey = normalizedKey.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
            let encodedBase = normalizedBase.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
            let url = URL(string: "https://v6.exchangerate-api.com/v6/\(encodedKey)/latest/\(encodedBase)")
        else {
            throw ExchangeRateAPIClientError.invalidURL
        }

        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ExchangeRateAPIClientError.nonHTTPResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw ExchangeRateAPIClientError.badStatusCode(httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Response.self, from: data)
        if decoded.result.lowercased() != "success" {
            let errorType = decoded.errorType?.replacingOccurrences(of: "_", with: " ") ?? "Unknown API error."
            throw ExchangeRateAPIClientError.apiError("ExchangeRate-API error: \(errorType).")
        }
        guard let baseCode = decoded.baseCode, let rawRates = decoded.conversionRates else {
            throw ExchangeRateAPIClientError.unsupportedResult(decoded.result)
        }

        let normalizedRates = rawRates.reduce(into: [String: Decimal]()) { partial, pair in
            partial[pair.key.uppercased()] = Decimal(pair.value)
        }
        let parsedUpdateDate = decoded.timeLastUpdateUTC.flatMap { Date.rfc2822Date(from: $0) }
        return ExchangeRateAPILatestPayload(
            baseCode: baseCode.uppercased(),
            conversionRates: normalizedRates,
            timeLastUpdateUTC: parsedUpdateDate
        )
    }
}

private extension ExchangeRateAPIClient {
    struct Response: Decodable {
        let result: String
        let errorType: String?
        let timeLastUpdateUTC: String?
        let baseCode: String?
        let conversionRates: [String: Double]?

        private enum CodingKeys: String, CodingKey {
            case result
            case errorType = "error-type"
            case timeLastUpdateUTC = "time_last_update_utc"
            case baseCode = "base_code"
            case conversionRates = "conversion_rates"
        }
    }
}

private extension Date {
    static func rfc2822Date(from raw: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        return formatter.date(from: raw)
    }
}
