import SwiftUI

struct CurrencyPickerView: View {
    @Binding var selectedCode: String
    var infoText: String?
    var showSuggestions: Bool = true
    var suggestions: [CurrencyOption] = CurrencyDataSource.suggested
    var options: [CurrencyOption] = CurrencyDataSource.all
    var excludedCodes: Set<String> = []
    var onSelect: ((String) -> Void)? = nil

    @State private var searchText: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let infoText {
                    Text(infoText)
                        .foregroundStyle(.secondary)
                }
                TextField("Type code or currency name", text: $searchText)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled(true)
                    .textFieldStyle(.roundedBorder)

                if showSuggestions && !featuredOptions.isEmpty {
                    Text("Popular choices")
                        .font(.subheadline.bold())
                    LazyVGrid(columns: gridColumns, spacing: 12) {
                        ForEach(featuredOptions, id: \.code) { option in
                            Button(action: {
                                select(code: option.code)
                            }) {
                                VStack(spacing: 4) {
                                    Text(option.code)
                                        .font(.headline)
                                    Text(option.name)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(selectedCode.uppercased() == option.code.uppercased() ? Color.accentColor.opacity(0.15) : Color(.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(hasSearchQuery ? "Matches" : "Browse currencies")
                        .font(.subheadline.bold())
                    if displayedOptions.isEmpty {
                        Text(hasSearchQuery ? "No currencies match your search." : "No currencies available.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(displayedOptions, id: \.code) { option in
                            Button(action: {
                                select(code: option.code)
                            }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(option.code)
                                            .font(.body.weight(.semibold))
                                        Text(option.name)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if selectedCode.uppercased() == option.code.uppercased() {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(Color.accentColor)
                                    }
                                }
                                .padding(.vertical, 8)
                            }
                            .buttonStyle(.plain)
                            Divider()
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical)
        }
    }

    private var displayedOptions: [CurrencyOption] {
        let filtered = CurrencyDataSource.filteredOptions(
            query: searchText,
            options: options,
            excluding: excludedCodes
        )
        return Array(filtered.prefix(40))
    }

    private var hasSearchQuery: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var gridColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 90), spacing: 12)]
    }

    private var featuredOptions: [CurrencyOption] {
        guard !hasSearchQuery else { return [] }
        let optionsByCode = Dictionary(uniqueKeysWithValues: options.map { ($0.code.uppercased(), $0) })
        var merged: [CurrencyOption] = []
        if let selectedOption = optionsByCode[selectedCode.uppercased()] {
            merged.append(selectedOption)
        }
        merged.append(contentsOf: suggestions)
        return uniqueByCode(merged)
            .filter { !excludedCodes.contains($0.code.uppercased()) }
            .prefix(8)
            .map { $0 }
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

    private func select(code: String) {
        selectedCode = code.uppercased()
        onSelect?(code.uppercased())
    }
}
