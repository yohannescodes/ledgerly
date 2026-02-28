import SwiftUI

struct ExchangeRateFormView: View {
    let baseCurrency: String
    let onSave: (String, Decimal) -> Void
    let onDelete: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCurrency: String
    @State private var rateValue: Decimal
    @State private var currencySearch: String = ""

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
                    TextField("Search code or currency name", text: $currencySearch)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)

                    if displayedCurrencyOptions.isEmpty {
                        Text("No currencies found.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(displayedCurrencyOptions, id: \.code) { option in
                            Button(action: { selectedCurrency = option.code }) {
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(option.name)
                                        Text(option.code)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if selectedCurrency.uppercased() == option.code.uppercased() {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(Color.accentColor)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
                        }
                    }
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

    private var displayedCurrencyOptions: [CurrencyOption] {
        let trimmed = currencySearch.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseUpper = baseCurrency.uppercased()
        let filtered: [CurrencyOption]
        if trimmed.isEmpty {
            let selectedOption = CurrencyDataSource.all.first { $0.code.uppercased() == selectedCurrency.uppercased() }
            let suggestions = CurrencyDataSource.suggested
            let merged = [selectedOption].compactMap { $0 } + suggestions
            let unique = uniqueByCode(merged).filter { $0.code.uppercased() != baseUpper }
            if unique.isEmpty {
                filtered = CurrencyDataSource.all.filter { $0.code.uppercased() != baseUpper }.prefix(20).map { $0 }
            } else {
                filtered = unique
            }
        } else {
            filtered = CurrencyDataSource.all.filter { option in
                option.code.uppercased() != baseUpper &&
                (option.code.localizedCaseInsensitiveContains(trimmed) || option.name.localizedCaseInsensitiveContains(trimmed))
            }
        }
        return Array(filtered.prefix(30))
    }

    private func uniqueByCode(_ options: [CurrencyOption]) -> [CurrencyOption] {
        var seen: Set<String> = []
        var result: [CurrencyOption] = []
        for option in options {
            let code = option.code.uppercased()
            if seen.insert(code).inserted {
                result.append(option)
            }
        }
        return result
    }
}
