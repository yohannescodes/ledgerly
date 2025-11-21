import SwiftUI

struct InvestmentsView: View {
    @EnvironmentObject private var investmentsStore: InvestmentsStore
    @State private var isRefreshing = false
    @State private var refreshError: String?

    var body: some View {
        List {
            ForEach(investmentsStore.accounts) { account in
                NavigationLink(destination: InvestmentAccountDetailView(account: account)) {
                    accountRow(account)
                }
            }
        }
        .navigationTitle("Investments")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: refreshPrices) {
                    if isRefreshing {
                        ProgressView()
                    } else {
                        Image(systemName: "arrow.clockwise.circle")
                    }
                }
            }
        }
        .onAppear(perform: refreshPrices)
        .alert("Price Refresh", isPresented: Binding(get: { refreshError != nil }, set: { if !$0 { refreshError = nil } })) {
            Button("OK", role: .cancel) { refreshError = nil }
        } message: {
            Text(refreshError ?? "")
        }
    }

    private func accountRow(_ account: InvestmentAccountModel) -> some View {
        VStack(alignment: .leading) {
            Text(account.name)
                .font(.headline)
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

    private func refreshPrices() {
        guard !isRefreshing else { return }
        isRefreshing = true
        Task {
            defer { isRefreshing = false }
            investmentsStore.refreshPrices()
        }
    }
}

struct HoldingRow: View {
    let lot: HoldingLotModel

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(lot.asset.symbol)
                    .font(.headline)
                Text(lot.asset.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text("Qty: \(format(quantity: lot.quantity))")
                    .font(.subheadline)
                Text("Value: \(format(currency: lot.marketValue, code: lot.asset.currencyCode))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let percent = lot.percentChange {
                    Text(changeText(percent: percent))
                        .font(.caption2)
                        .foregroundStyle(percent >= 0 ? Color.green : Color.red)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func format(quantity: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 4
        return formatter.string(from: quantity as NSNumber) ?? "--"
    }

    private func format(currency value: Decimal, code: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        return formatter.string(from: value as NSNumber) ?? "--"
    }

    private func changeText(percent: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        let formatted = formatter.string(from: percent as NSNumber) ?? "0"
        return formatted + "%"
    }
}

#Preview {
    InvestmentsView()
        .environmentObject(InvestmentsStore(persistence: PersistenceController.preview))
}
