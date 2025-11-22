import SwiftUI
import CoreData

struct AddHoldingView: View {
    let account: InvestmentAccountModel
    let wallets: [WalletModel]
    let onSave: (InvestmentHoldingInput) -> Void
    @State private var input: InvestmentHoldingInput
    @Environment(\.dismiss) private var dismiss

    init(account: InvestmentAccountModel, wallets: [WalletModel], onSave: @escaping (InvestmentHoldingInput) -> Void) {
        self.account = account
        self.wallets = wallets
        self.onSave = onSave
        _input = State(initialValue: InvestmentHoldingInput(currencyCode: account.currencyCode))
    }

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
                    DatePicker("Acquired", selection: $input.date, displayedComponents: .date)
                    Picker("Funded from", selection: $input.walletID) {
                        Text("None").tag(Optional<NSManagedObjectID>(nil))
                        ForEach(wallets) { wallet in
                            Text(wallet.name).tag(Optional(wallet.id))
                        }
                    }
                    NavigationLink {
                        CurrencyPickerView(selectedCode: $input.currencyCode, infoText: "Cost / unit currency")
                    } label: {
                        HStack {
                            Text("Cost Currency")
                            Spacer()
                            Text(input.currencyCode)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Add Holding")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: dismiss.callAsFunction) }
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

struct InvestmentHoldingInput {
    var symbol: String = ""
    var name: String = ""
    var assetType: String = "stock"
    var quantity: Decimal = .zero
    var costPerUnit: Decimal = .zero
    var date: Date = Date()
    var walletID: NSManagedObjectID? = nil
    var currencyCode: String = Locale.current.currency?.identifier ?? "USD"

    init(symbol: String = "", name: String = "", assetType: String = "stock", quantity: Decimal = .zero, costPerUnit: Decimal = .zero, date: Date = Date(), walletID: NSManagedObjectID? = nil, currencyCode: String = Locale.current.currency?.identifier ?? "USD") {
        self.symbol = symbol
        self.name = name
        self.assetType = assetType
        self.quantity = quantity
        self.costPerUnit = costPerUnit
        self.date = date
        self.walletID = walletID
        self.currencyCode = currencyCode
    }
}
