import SwiftUI

struct AddInvestmentAccountView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var input = InvestmentAccountFormInput()
    let onSave: (InvestmentAccountFormInput) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Account Name", text: $input.name)
                    TextField("Institution", text: $input.institution)
                    Picker("Type", selection: $input.accountType) {
                        Text("Brokerage").tag("brokerage")
                        Text("Retirement").tag("retirement")
                        Text("Exchange").tag("exchange")
                        Text("Wallet").tag("wallet")
                    }
                }
                Section("Currency") {
                    NavigationLink {
                        CurrencyPickerView(selectedCode: $input.currencyCode)
                    } label: {
                        HStack {
                            Text("Base Currency")
                            Spacer()
                            Text(input.currencyCode)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("New Account")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: dismiss.callAsFunction)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(input.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func save() {
        onSave(input)
        dismiss()
    }
}
