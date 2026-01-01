import SwiftUI

struct TransactionRow: View {
    let model: TransactionModel
    let converter: CurrencyConverter
    let baseCurrencyCode: String

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(model.category?.name ?? model.direction.capitalized)
                    .font(.headline)
                Text(model.walletName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(formattedBaseAmount)
                    .font(.headline)
                    .foregroundStyle(model.direction == "expense" ? Color.red : Color.green)
                if let nativeAmountSummary {
                    Text(nativeAmountSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 6)
    }

    private var formattedBaseAmount: String {
        let amount = converter.convertToBase(model.amount, currency: model.currencyCode)
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = baseCurrencyCode
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "--"
    }

    private var nativeAmountSummary: String? {
        guard model.currencyCode.uppercased() != baseCurrencyCode.uppercased() else { return nil }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = model.currencyCode
        let amountString = formatter.string(from: NSDecimalNumber(decimal: model.amount)) ?? "--"
        return "\(amountString) \(model.currencyCode)"
    }
}
