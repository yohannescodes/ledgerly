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
        VStack(alignment: .leading, spacing: 16) {
            if let infoText {
                Text(infoText)
                    .foregroundStyle(.secondary)
            }
            TextField("Search currency", text: $searchText)
                .textFieldStyle(.roundedBorder)

            if showSuggestions && !suggestions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(suggestions, id: \.code) { option in
                            Button(action: {
                                selectedCode = option.code
                                onSelect?(option.code)
                            }) {
                                Text(option.code)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(selectedCode == option.code ? Color.accentColor.opacity(0.2) : Color(.systemGray5))
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(filteredOptions, id: \.code) { option in
                        Button(action: {
                            selectedCode = option.code
                            onSelect?(option.code)
                        }) {
                            HStack {
                                VStack(alignment: .leading) {
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
                    }
                }
            }
        }
    }

    private var filteredOptions: [CurrencyOption] {
        let trimmed = searchText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return options }
        return options.filter { option in
            option.code.localizedCaseInsensitiveContains(trimmed) ||
            option.name.localizedCaseInsensitiveContains(trimmed)
        }
    }
}
