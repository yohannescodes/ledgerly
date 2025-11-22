import CoreData
import Foundation

struct CurrencyConverter {
    let baseCurrency: String
    let rates: [String: Decimal]

    func convertToBase(_ amount: Decimal, currency: String?) -> Decimal {
        guard let code = currency?.uppercased(), !code.isEmpty else { return amount }
        if code == baseCurrency.uppercased() { return amount }
        guard let rate = rates[code] else { return amount }
        return amount * rate
    }

    func convert(_ amount: Decimal, from source: String?, to target: String) -> Decimal {
        let baseAmount = convertToBase(amount, currency: source)
        return convertFromBase(baseAmount, to: target)
    }

    func convertFromBase(_ amount: Decimal, to target: String) -> Decimal {
        let upper = target.uppercased()
        if upper == baseCurrency.uppercased() { return amount }
        guard let rate = rates[upper], rate != .zero else { return amount }
        return amount / rate
    }
}

extension CurrencyConverter {
    static func fromSettings(in context: NSManagedObjectContext) -> CurrencyConverter {
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
}
