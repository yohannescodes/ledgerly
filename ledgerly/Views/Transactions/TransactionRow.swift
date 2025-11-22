import SwiftUI

struct TransactionRow: View {
    let model: TransactionModel

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
                Text(formattedAmount)
                    .font(.headline)
                    .foregroundStyle(model.direction == "expense" ? Color.red : Color.green)
                Text(model.currencyCode)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }

    private var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = model.currencyCode
        return formatter.string(from: model.amount as NSNumber) ?? "--"
    }
}
