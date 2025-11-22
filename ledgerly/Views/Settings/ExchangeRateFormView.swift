import SwiftUI

struct ExchangeRateFormView: View {
    let baseCurrency: String
    let onSave: (String, Decimal) -> Void
    let onDelete: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCurrency: String
    @State private var rateValue: Decimal

    init(baseCurrency: String, selectedCurrency: String? = nil, rateValue: Decimal? = nil, onSave: @escaping (String, Decimal) -> Void, onDelete: (() -> Void)? = nil) {
        self.baseCurrency = baseCurrency
        self.onSave = onSave
        self.onDelete = onDelete
        _selectedCurrency = State(initialValue: selectedCurrency ?? baseCurrency)
        _rateValue = State(initialValue: rateValue ?? 1)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Foreign Currency") {
                    CurrencyPickerView(selectedCode: $selectedCurrency)
                }
                Section("Conversion") {
                    DecimalTextField(title: "1 \(selectedCurrency) equals", value: $rateValue)
                    HStack {
                        Spacer()
                        Text("\(baseCurrency)")
                            .font(.headline)
                        Spacer()
                    }
                }
                if let onDelete {
                    Section {
                        Button(role: .destructive) {
                            onDelete()
                            dismiss()
                        } label: {
                            Text("Delete Rate")
                        }
                    }
                }
            }
            .navigationTitle(onDelete == nil ? "New Exchange Rate" : "Edit Exchange Rate")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: dismiss.callAsFunction)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
            }
        }
    }

    private var canSave: Bool {
        selectedCurrency.uppercased() != baseCurrency.uppercased() && rateValue > 0
    }

    private func save() {
        onSave(selectedCurrency.uppercased(), rateValue)
        dismiss()
    }
}
