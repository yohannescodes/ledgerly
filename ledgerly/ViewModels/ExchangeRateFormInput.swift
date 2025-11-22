import Foundation

struct ExchangeRateFormInput {
    var fromCurrency: String
    var toCurrency: String
    var rate: Decimal

    init(
        fromCurrency: String = Locale.current.currency?.identifier ?? "USD",
        toCurrency: String,
        rate: Decimal = 1
    ) {
        self.fromCurrency = fromCurrency
        self.toCurrency = toCurrency
        self.rate = rate
    }
}
