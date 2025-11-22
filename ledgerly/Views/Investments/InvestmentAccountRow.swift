import SwiftUI

struct InvestmentAccountRow: View {
    let account: InvestmentAccountModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(account.name)
                    .font(.headline)
                Spacer()
                Text(formatCurrency(account.marketValue))
                    .font(.headline)
            }
            if let institution = account.institution {
                Text(institution)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Text("Holdings: \(account.holdings.count)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = Locale.current.currency?.identifier ?? "USD"
        return formatter.string(from: value as NSNumber) ?? "--"
    }
}
