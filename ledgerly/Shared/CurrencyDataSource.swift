import Foundation

struct CurrencyOption: Identifiable, Hashable {
    let code: String
    let name: String

    var id: String { code }
}

enum CurrencyDataSource {
    static let all: [CurrencyOption] = {
        let locale = Locale.current
        let codes = Locale.commonISOCurrencyCodes
        return codes.compactMap { code in
            let name = locale.localizedString(forCurrencyCode: code) ?? code
            return CurrencyOption(code: code, name: name)
        }
        .sorted { lhs, rhs in
            if lhs.name == rhs.name {
                return lhs.code < rhs.code
            }
            return lhs.name < rhs.name
        }
    }()

    static let suggested: [CurrencyOption] = {
        let favorites = [Locale.current.currency?.identifier, "USD", "EUR", "GBP", "NGN"].compactMap { $0 }
        let unique = Array(Set(favorites))
        let map = Dictionary(uniqueKeysWithValues: all.map { ($0.code, $0) })
        return unique.compactMap { map[$0] }
    }()
}
