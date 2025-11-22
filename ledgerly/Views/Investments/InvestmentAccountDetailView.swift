import SwiftUI
import Charts
import CoreData

struct InvestmentAccountDetailView: View {
    let account: InvestmentAccountModel
    @EnvironmentObject private var investmentsStore: InvestmentsStore
    @EnvironmentObject private var walletsStore: WalletsStore
    @EnvironmentObject private var netWorthStore: NetWorthStore
    @State private var showingAddForm = false
    @State private var showingTransferSheet = false
    @State private var lotToSell: HoldingLotModel?

    private var resolvedAccount: InvestmentAccountModel {
        investmentsStore.accounts.first(where: { $0.id == account.id }) ?? account
    }

    var body: some View {
        List {
            summarySection

            Section(header: Text("Holdings")) {
                if resolvedAccount.holdings.isEmpty {
                    Text("No holdings yet").foregroundStyle(.secondary)
                } else {
                    ForEach(resolvedAccount.holdings) { lot in
                        HoldingRow(lot: lot)
                            .swipeActions {
                                Button("Sell") { lotToSell = lot }
                                    .tint(.blue)
                                Button(role: .destructive) {
                                    investmentsStore.deleteHolding(lotID: lot.id)
                                    netWorthStore.reload()
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        if !lot.sales.isEmpty {
                            SaleHistoryList(sales: lot.sales)
                        }
                    }
                }
            }
        }
        .navigationTitle(resolvedAccount.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingAddForm = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddForm) {
            AddHoldingView(account: account, wallets: walletsStore.wallets) { input in
                investmentsStore.addHolding(
                    accountID: account.id,
                    symbol: input.symbol,
                    assetName: input.name,
                    assetType: input.assetType,
                    quantity: input.quantity,
                    costPerUnit: input.costPerUnit,
                    acquiredDate: input.date,
                    currencyCode: input.currencyCode,
                    fundingWalletID: input.walletID
                )
                netWorthStore.reload()
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showingTransferSheet) {
            WalletTransferForm(holdingCost: resolvedAccount.totalCost) { input in
                guard let walletID = input.walletID else { return }
                investmentsStore.addHolding(
                    accountID: account.id,
                    symbol: account.name + " Transfer",
                    assetName: "Wallet Transfer",
                    assetType: "cash",
                    quantity: 0,
                    costPerUnit: 0,
                    acquiredDate: Date(),
                    currencyCode: account.currencyCode,
                    fundingWalletID: walletID
                )
            }
        }
        .sheet(item: $lotToSell) { lot in
            SellHoldingForm(lot: lot) { sellInput in
                guard let walletID = sellInput.walletID else { return }
                investmentsStore.sellHolding(
                    lotID: lot.id,
                    quantity: min(sellInput.quantity, lot.quantity),
                    salePrice: sellInput.price,
                    destinationWalletID: walletID
                )
                netWorthStore.reload()
            }
        }
    }

    private var summarySection: some View {
        Section("Summary") {
            MetricRow(title: "Market Value", value: resolvedAccount.marketValue)
            MetricRow(title: "Cost Basis", value: resolvedAccount.totalCost)
            MetricRow(title: "Unrealized", value: resolvedAccount.unrealizedGain)
            if let percent = resolvedAccount.gainPercent {
                Text("Gain %: \(formatPercent(percent))")
                    .font(.subheadline)
                    .foregroundStyle(percent >= 0 ? Color.green : Color.red)
            }
            SparklineChart(points: resolvedAccount.holdings.flatMap { $0.asset.sparklinePoints })
            Button("Record Wallet Transfer", action: { showingTransferSheet = true })
        }
    }

    private func formatPercent(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        return (formatter.string(from: value as NSNumber) ?? "0") + "%"
    }
}

struct AddHoldingInput {
    var symbol: String = ""
    var name: String = ""
    var assetType: String = "stock"
    var quantity: Decimal = .zero
    var costPerUnit: Decimal = .zero
    var acquiredDate: Date = Date()
    var walletID: NSManagedObjectID?
}

struct AddHoldingFormView: View {
    let account: InvestmentAccountModel
    let onSave: (AddHoldingInput) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var input = AddHoldingInput()
    @EnvironmentObject private var walletsStore: WalletsStore

    var body: some View {
        NavigationStack {
            Form {
                Section("Asset") {
                    TextField("Symbol", text: $input.symbol)
                        .textInputAutocapitalization(.characters)
                    TextField("Name", text: $input.name)
                    Picker("Type", selection: $input.assetType) {
                        Text("Stock").tag("stock")
                        Text("ETF").tag("etf")
                        Text("Crypto").tag("crypto")
                    }
                }

                Section("Position") {
                    DecimalTextField(title: "Quantity", value: $input.quantity)
                    DecimalTextField(title: "Cost / Unit", value: $input.costPerUnit)
                    DatePicker("Acquired", selection: $input.acquiredDate, displayedComponents: .date)
                    Picker("Fund from", selection: $input.walletID) {
                        Text("None").tag(Optional<NSManagedObjectID>(nil))
                        ForEach(walletsStore.wallets) { wallet in
                            Text(wallet.name).tag(Optional(wallet.id))
                        }
                    }
                }
            }
            .navigationTitle("Add Holding")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: dismiss.callAsFunction)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!canSave)
                }
            }
        }
    }

    private var canSave: Bool {
        !input.symbol.isEmpty && !input.name.isEmpty && input.quantity > 0 && input.costPerUnit > 0
    }

    private func save() {
        onSave(input)
        dismiss()
    }
}

private struct MetricRow: View {
    let title: String
    let value: Decimal

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(formatCurrency(value))
                .fontWeight(.semibold)
        }
    }

    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = Locale.current.currency?.identifier ?? "USD"
        return formatter.string(from: value as NSNumber) ?? "--"
    }
}

private struct SparklineChart: View {
    let points: [PricePoint]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Recent Trend")
                .font(.caption)
                .foregroundStyle(.secondary)
            if points.isEmpty {
                Text("No price history")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Chart(points) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Price", (point.value as NSDecimalNumber).doubleValue)
                    )
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .frame(height: 100)
            }
        }
    }
}

private struct SaleHistoryList: View {
    let sales: [HoldingSaleModel]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Sale History")
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(sales.prefix(3)) { sale in
                HStack {
                    Text(sale.date, style: .date)
                    Spacer()
                    Text("Qty: \(sale.quantity as NSDecimalNumber)")
                    Text(formatCurrency(sale.price))
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = Locale.current.currency?.identifier ?? "USD"
        return formatter.string(from: value as NSNumber) ?? "--"
    }
}
