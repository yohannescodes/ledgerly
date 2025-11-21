import SwiftUI
import Combine

struct InvestmentAccountDetailView: View {
    let account: InvestmentAccountModel
    @EnvironmentObject private var investmentsStore: InvestmentsStore
    @EnvironmentObject private var netWorthStore: NetWorthStore
    @State private var showingAddForm = false
    @State private var showingTransferSheet = false

    private var resolvedAccount: InvestmentAccountModel {
        investmentsStore.accounts.first(where: { $0.id == account.id }) ?? account
    }

    var body: some View {
        List {
            summarySection
            Section(header: Text("Holdings")) {
                if resolvedAccount.holdings.isEmpty {
                    Text("No holdings yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(resolvedAccount.holdings) { lot in
                        HoldingRow(lot: lot)
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
            AddHoldingFormView(account: account) { input in
                investmentsStore.addHolding(
                    accountID: account.id,
                    symbol: input.symbol,
                    assetName: input.name,
                    assetType: input.assetType,
                    quantity: input.quantity,
                    costPerUnit: input.costPerUnit,
                    acquiredDate: input.acquiredDate
                )
                netWorthStore.reload()
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showingTransferSheet) {
            WalletTransferPlaceholderView()
        }
        .onChange(of: investmentsStore.accounts) { _ in }
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
            SparklinePlaceholder()
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
}

struct AddHoldingFormView: View {
    let account: InvestmentAccountModel
    let onSave: (AddHoldingInput) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var input = AddHoldingInput()

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

private struct DecimalTextField: View {
    let title: String
    @Binding var value: Decimal
    @State private var text: String = ""

    var body: some View {
        TextField(title, text: Binding(
            get: {
                if text.isEmpty {
                    return value == .zero ? "" : NSDecimalNumber(decimal: value).stringValue
                }
                return text
            },
            set: { newValue in
                text = newValue
                if let decimal = Decimal(string: newValue) {
                    value = decimal
                }
            }
        ))
        .keyboardType(.decimalPad)
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

private struct SparklinePlaceholder: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Last 7 days")
                .font(.caption)
                .foregroundStyle(.secondary)
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
                    .frame(height: 60)
                Path { path in
                    let points = stride(from: 0, through: 1, by: 0.2).map { CGFloat($0) }
                    path.move(to: CGPoint(x: 0, y: 30))
                    for point in points {
                        let y = 30 + sin(point * .pi * 2) * 20
                        path.addLine(to: CGPoint(x: point * 120, y: y))
                    }
                }
                .stroke(Color.accentColor, lineWidth: 2)
                .frame(height: 60)
            }
        }
    }
}

private struct WalletTransferPlaceholderView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("Wallet transfers will let you link investment buys/sells to cash movements soon.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Button("Close", action: dismiss.callAsFunction)
                    .buttonStyle(.borderedProminent)
            }
            .padding()
            .navigationTitle("Wallet Transfer")
        }
    }
}
