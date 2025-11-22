import Foundation

struct ManualEntryInput {
    var name: String = ""
    var amount: Decimal = .zero
    var currencyCode: String = Locale.current.currency?.identifier ?? "USD"
}
