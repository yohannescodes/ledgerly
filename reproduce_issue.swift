import Foundation

// Mock structs
struct ManualAsset {
    var name: String?
    var investmentSymbol: String?
    var investmentQuantity: Decimal?
    var investmentCostPerUnit: Decimal?
    var marketPrice: Decimal?
    var currencyCode: String?
    var marketPriceUpdatedAt: Date?
    var investmentContractMultiplier: Decimal?
    var investmentProvider: String?
}

struct CurrencyConverter {
    var baseCurrency: String
    var rates: [String: Double]
    
    func convertToBase(_ amount: Decimal, currency: String) -> Decimal {
        if currency == baseCurrency { return amount }
        // Mock conversion
        return amount
    }
}

struct InvestmentSummary {
    let title: String
    let currentValue: Decimal
    let costBasis: Decimal
    let profit: Decimal
    let currencyCode: String
    
    var profitString: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        let formatted = formatter.string(from: profit as NSNumber) ?? "--"
        return profit >= 0 ? "+" + formatted : formatted
    }
}

func investmentSummary(for asset: ManualAsset, converter: CurrencyConverter) -> InvestmentSummary {
    let baseCurrency = converter.baseCurrency.uppercased()
    let nativeCurrency = (asset.currencyCode ?? baseCurrency).uppercased()
    let quantity = asset.investmentQuantity ?? .zero
    let costPerUnit = asset.investmentCostPerUnit ?? .zero
    let currentPrice = asset.marketPrice ?? costPerUnit
    let nativeCostBasis = quantity * costPerUnit
    let nativeCurrentValue = quantity * currentPrice
    
    // Simplified conversion
    let costBasis = nativeCostBasis
    let currentValue = nativeCurrentValue
    
    let profit = currentValue - costBasis
    let title = asset.name ?? "Investment"
    
    return InvestmentSummary(
        title: title,
        currentValue: currentValue,
        costBasis: costBasis,
        profit: profit,
        currencyCode: nativeCurrency
    )
}

// Simulation
let converter = CurrencyConverter(baseCurrency: "USD", rates: [:])

// Case 1: Stock (AAPL)
// Price 200. Quantity 10. Cost 150.
var aapl = ManualAsset(
    name: "Apple",
    investmentSymbol: "AAPL",
    investmentQuantity: 10,
    investmentCostPerUnit: 150,
    marketPrice: 200, // Fetched price
    currencyCode: "USD",
    investmentContractMultiplier: 1,
    investmentProvider: "stock"
)

let aaplSummary = investmentSummary(for: aapl, converter: converter)
print("AAPL:")
print("Value: \(aaplSummary.currentValue)")
print("Profit: \(aaplSummary.profitString)")
print("---")

// Case 2: Index (S&P 500) - RESTORED
// Index Level 6000.
// User holds 1 contract.
// Multiplier 10 (Restored).
// AlphaVantage returns 600 (Mock - 1/10th of index).
// ManualInvestmentPriceService applies multiplier: 600 * 10 = 6000.
// MarketPrice stored as 6000.

var gspc = ManualAsset(
    name: "S&P 500",
    investmentSymbol: "GSPC",
    investmentQuantity: 1,
    investmentCostPerUnit: 6000,
    marketPrice: 6000, // 600 * 10
    currencyCode: "USD",
    investmentContractMultiplier: 10,
    investmentProvider: "stock"
)

let gspcSummary = investmentSummary(for: gspc, converter: converter)
print("GSPC (Multiplier 10 - Restored):")
print("Value: \(gspcSummary.currentValue)")
print("Profit: \(gspcSummary.profitString)")
print("---")

// Case 3: Index (S&P 500) - User expects Value 6000.
// Maybe user entered Cost 600?
var gspc2 = ManualAsset(
    name: "S&P 500",
    investmentSymbol: "GSPC",
    investmentQuantity: 1,
    investmentCostPerUnit: 600, // User entered 1/10th
    marketPrice: 60000, // 6000 * 10
    currencyCode: "USD",
    investmentContractMultiplier: 10,
    investmentProvider: "stock"
)

let gspc2Summary = investmentSummary(for: gspc2, converter: converter)
print("GSPC (Cost 600):")
print("Value: \(gspc2Summary.currentValue)")
print("Profit: \(gspc2Summary.profitString)")
print("---")
