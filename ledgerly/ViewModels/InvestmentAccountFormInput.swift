import Foundation

struct InvestmentAccountFormInput {
    var name: String = ""
    var institution: String = ""
    var accountType: String = "brokerage"
    var currencyCode: String = Locale.current.currency?.identifier ?? "USD"
}
