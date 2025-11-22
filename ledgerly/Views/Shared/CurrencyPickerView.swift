import SwiftUI

struct CurrencyPickerView: View {
    @Binding var selectedCode: String
    var infoText: String?
    var showSuggestions: Bool = true
    var suggestions: [CurrencyOption] = CurrencyDataSource.suggested
    var options: [CurrencyOption] = CurrencyDataSource.all
    var onSelect: ((String) -> Void)? = nil

    @State private var searchText: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let infoText {
                    Text(infoText)
                        .foregroundStyle(.secondary)
                }
                TextField("Search currency", text: $searchText)
                    .textFieldStyle(.roundedBorder)

                if showSuggestions && !suggestions.isEmpty {
                    Text("Popular choices")
                        .font(.subheadline.bold())
                    LazyVGrid(columns: gridColumns, spacing: 12) {
                        ForEach(suggestions, id: \.code) { option in
                            Button(action: {
                                selectedCode = option.code
                                onSelect?(option.code)
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
                                .background(selectedCode == option.code ? Color.accentColor.opacity(0.15) : Color(.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if hasSearchQuery {
                    if filteredOptions.isEmpty {
                        Text("No currencies match your search.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(filteredOptions, id: \.code) { option in
                                Button(action: {
                                    selectedCode = option.code
                                    onSelect?(option.code)
                                }) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(option.name)
                                            Text(option.code)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        if selectedCode == option.code {
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
                } else {
                    Text("Search for a code or currency name to view every option.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical)
        }
    }

    private var filteredOptions: [CurrencyOption] {
        let trimmed = searchText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return [] }
        return options.filter { option in
            option.code.localizedCaseInsensitiveContains(trimmed) ||
            option.name.localizedCaseInsensitiveContains(trimmed)
        }
    }

    private var hasSearchQuery: Bool {
        !searchText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var gridColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 90), spacing: 12)]
    }
}
