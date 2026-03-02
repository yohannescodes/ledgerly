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

    static func filteredOptions(
        query: String,
        options: [CurrencyOption] = all,
        excluding excludedCodes: Set<String> = []
    ) -> [CurrencyOption] {
        let normalizedExcludedCodes = Set(excludedCodes.map { $0.uppercased() })
        let availableOptions = options.filter { !normalizedExcludedCodes.contains($0.code.uppercased()) }
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return availableOptions }

        let queryUpper = trimmedQuery.uppercased()
        return availableOptions
            .map { option in
                (option: option, score: matchScore(for: option, queryUpper: queryUpper, queryRaw: trimmedQuery))
            }
            .filter { $0.score < Int.max }
            .sorted { lhs, rhs in
                if lhs.score == rhs.score {
                    return lhs.option.name < rhs.option.name
                }
                return lhs.score < rhs.score
            }
            .map(\.option)
    }

    private static func matchScore(for option: CurrencyOption, queryUpper: String, queryRaw: String) -> Int {
        let code = option.code.uppercased()
        if code == queryUpper { return 0 }
        if code.hasPrefix(queryUpper) { return 1 }
        if code.contains(queryUpper) { return 2 }
        if option.name.localizedCaseInsensitiveContains(queryRaw) {
            if option.name.lowercased().hasPrefix(queryRaw.lowercased()) { return 3 }
            return 4
        }
        return Int.max
    }
}
