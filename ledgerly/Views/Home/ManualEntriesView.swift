import SwiftUI
import CoreData

struct ManualEntriesView: View {
    @Environment(\.managedObjectContext) private var context
    @EnvironmentObject private var netWorthStore: NetWorthStore
    @EnvironmentObject private var appSettingsStore: AppSettingsStore

    @FetchRequest(
        sortDescriptors: [SortDescriptor(\.valuationDate, order: .reverse)],
        predicate: NSPredicate(format: "NOT (type CONTAINS[cd] %@) AND NOT (type CONTAINS[cd] %@)", "receiv", "investment")
    )
    private var assets: FetchedResults<ManualAsset>

    @FetchRequest(
        sortDescriptors: [SortDescriptor(\.valuationDate, order: .reverse)],
        predicate: NSPredicate(format: "type CONTAINS[cd] %@", "receiv")
    )
    private var receivables: FetchedResults<ManualAsset>

    @FetchRequest(
        sortDescriptors: [SortDescriptor(\.valuationDate, order: .reverse)],
        predicate: NSPredicate(format: "type CONTAINS[cd] %@", "investment")
    )
    private var investments: FetchedResults<ManualAsset>

    @FetchRequest(sortDescriptors: [SortDescriptor(\.dueDate, order: .reverse)])
    private var liabilities: FetchedResults<ManualLiability>

    @State private var showingAssetForm = false
    @State private var showingReceivableForm = false
    @State private var showingInvestmentForm = false
    @State private var showingLiabilityForm = false
    @State private var assetToEdit: ManualAsset?
    @State private var receivableToEdit: ManualAsset?
    @State private var investmentToEdit: ManualAsset?
    @State private var liabilityToEdit: ManualLiability?

    var body: some View {
        List {
            Section("Assets") {
                ForEach(assets) { asset in
                    VStack(alignment: .leading) {
                        Text(asset.name ?? "Asset")
                        Text(formatCurrency(asset.value as Decimal? ?? .zero, code: asset.currencyCode ?? "USD"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { assetToEdit = asset }
                }
                .onDelete(perform: deleteAsset)
                Button("Add Asset", action: { showingAssetForm = true })
            }

            Section("Receivables") {
                ForEach(receivables) { receivable in
                    VStack(alignment: .leading) {
                        Text(receivable.name ?? "Receivable")
                        Text(formatCurrency(receivable.value as Decimal? ?? .zero, code: receivable.currencyCode ?? "USD"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { receivableToEdit = receivable }
                }
                .onDelete(perform: deleteReceivable)
                Button("Add Receivable", action: { showingReceivableForm = true })
            }

            Section("Investments") {
                if investments.isEmpty {
                    Text("Log coins, contracts, or other holdings with purchase cost. We'll keep prices updated.")
                        .foregroundStyle(.secondary)
                }
                ForEach(investments) { investment in
                    investmentRow(for: investment)
                        .contentShape(Rectangle())
                        .onTapGesture { investmentToEdit = investment }
                }
                .onDelete(perform: deleteInvestment)
                Button("Add Investment", action: { showingInvestmentForm = true })
            }

            Section("Liabilities") {
                ForEach(liabilities) { liability in
                    VStack(alignment: .leading) {
                        Text(liability.name ?? "Liability")
                        Text(formatCurrency(liability.balance as Decimal? ?? .zero, code: liability.currencyCode ?? "USD"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { liabilityToEdit = liability }
                }
                .onDelete(perform: deleteLiability)
                Button("Add Liability", action: { showingLiabilityForm = true })
            }
        }
        .navigationTitle("Manual Entries")
        .sheet(isPresented: $showingAssetForm) {
            ManualEntryFormView(title: "New Asset") { entry in
                ManualAsset.create(in: context, name: entry.name, type: "tangible", value: entry.amount, currencyCode: entry.currencyCode)
                try? context.save()
                netWorthStore.reload()
            }
        }
        .sheet(isPresented: $showingReceivableForm) {
            ManualEntryFormView(title: "New Receivable") { entry in
                ManualAsset.create(in: context, name: entry.name, type: "receivable", value: entry.amount, currencyCode: entry.currencyCode)
                try? context.save()
                netWorthStore.reload()
            }
        }
        .sheet(isPresented: $showingInvestmentForm) {
            InvestmentEntryFormView(title: "New Investment", baseCurrencyCode: appSettingsStore.snapshot.baseCurrencyCode) { entry in
                let identifier = formattedIdentifier(for: entry)
                ManualAsset.create(
                    in: context,
                    name: entry.name,
                    type: "investment",
                    value: entry.quantity * entry.costPerUnit,
                    currencyCode: entry.currencyCode,
                    includeInCore: true,
                    includeInTangible: false,
                    volatility: true,
                    investmentProvider: entry.kind.rawValue,
                    investmentCoinID: identifier,
                    investmentSymbol: entry.symbol,
                    investmentQuantity: entry.quantity,
                    investmentCostPerUnit: entry.costPerUnit,
                    marketPrice: entry.costPerUnit,
                    marketPriceCurrencyCode: entry.currencyCode
                )
                try? context.save()
                netWorthStore.reload()
            }
        }
        .sheet(isPresented: $showingLiabilityForm) {
            ManualEntryFormView(title: "New Liability") { entry in
                ManualLiability.create(in: context, name: entry.name, type: "loan", balance: entry.amount, currencyCode: entry.currencyCode)
                try? context.save()
                netWorthStore.reload()
            }
        }
        .sheet(isPresented: Binding(get: { assetToEdit != nil }, set: { if !$0 { assetToEdit = nil } })) {
            if let asset = assetToEdit {
                ManualEntryFormView(title: "Edit Asset", entry: ManualEntryInput(name: asset.name ?? "", amount: asset.value as Decimal? ?? .zero, currencyCode: asset.currencyCode ?? Locale.current.currency?.identifier ?? "USD"), onSave: { entry in
                    asset.name = entry.name
                    asset.value = NSDecimalNumber(decimal: entry.amount)
                    asset.currencyCode = entry.currencyCode
                    try? context.save()
                    netWorthStore.reload()
                    assetToEdit = nil
                }, onDelete: {
                    context.delete(asset)
                    try? context.save()
                    netWorthStore.reload()
                    assetToEdit = nil
                })
            }
        }
        .sheet(isPresented: Binding(get: { receivableToEdit != nil }, set: { if !$0 { receivableToEdit = nil } })) {
            if let receivable = receivableToEdit {
                ManualEntryFormView(title: "Edit Receivable", entry: ManualEntryInput(name: receivable.name ?? "", amount: receivable.value as Decimal? ?? .zero, currencyCode: receivable.currencyCode ?? Locale.current.currency?.identifier ?? "USD"), onSave: { entry in
                    receivable.name = entry.name
                    receivable.value = NSDecimalNumber(decimal: entry.amount)
                    receivable.currencyCode = entry.currencyCode
                    try? context.save()
                    netWorthStore.reload()
                    receivableToEdit = nil
                }, onDelete: {
                    context.delete(receivable)
                    try? context.save()
                    netWorthStore.reload()
                    receivableToEdit = nil
                })
            }
        }
        .sheet(isPresented: Binding(get: { investmentToEdit != nil }, set: { if !$0 { investmentToEdit = nil } })) {
            if let investment = investmentToEdit {
                InvestmentEntryFormView(
                    title: "Edit Investment",
                    baseCurrencyCode: appSettingsStore.snapshot.baseCurrencyCode,
                    entry: ManualInvestmentInput(
                        kind: (investment.investmentProvider == ManualInvestmentInput.Kind.stock.rawValue) ? .stock : .crypto,
                        name: investment.name ?? "",
                        coinID: investment.investmentCoinID ?? "",
                        symbol: investment.investmentSymbol ?? "",
                        quantity: investment.investmentQuantity as Decimal? ?? .zero,
                        costPerUnit: investment.investmentCostPerUnit as Decimal? ?? .zero,
                        currencyCode: investment.currencyCode ?? appSettingsStore.snapshot.baseCurrencyCode
                    ),
                    onSave: { entry in
                        let identifier = formattedIdentifier(for: entry)
                        investment.name = entry.name
                        investment.investmentProvider = entry.kind.rawValue
                        investment.investmentCoinID = identifier
                        investment.investmentSymbol = entry.symbol
                        investment.investmentQuantity = NSDecimalNumber(decimal: entry.quantity)
                        investment.investmentCostPerUnit = NSDecimalNumber(decimal: entry.costPerUnit)
                        investment.currencyCode = entry.currencyCode
                        investment.value = NSDecimalNumber(decimal: entry.quantity * entry.costPerUnit)
                        try? context.save()
                        netWorthStore.reload()
                        investmentToEdit = nil
                    },
                    onDelete: {
                        context.delete(investment)
                        try? context.save()
                        netWorthStore.reload()
                        investmentToEdit = nil
                    }
                )
            }
        }
        .sheet(isPresented: Binding(get: { liabilityToEdit != nil }, set: { if !$0 { liabilityToEdit = nil } })) {
            if let liability = liabilityToEdit {
                ManualEntryFormView(title: "Edit Liability", entry: ManualEntryInput(name: liability.name ?? "", amount: liability.balance as Decimal? ?? .zero, currencyCode: liability.currencyCode ?? Locale.current.currency?.identifier ?? "USD"), onSave: { entry in
                    liability.name = entry.name
                    liability.balance = NSDecimalNumber(decimal: entry.amount)
                    liability.currencyCode = entry.currencyCode
                    try? context.save()
                    netWorthStore.reload()
                    liabilityToEdit = nil
                }, onDelete: {
                    context.delete(liability)
                    try? context.save()
                    netWorthStore.reload()
                    liabilityToEdit = nil
                })
            }
        }
        .task(id: appSettingsStore.snapshot.baseCurrencyCode) {
            await ManualInvestmentPriceService.shared.refresh(baseCurrency: appSettingsStore.snapshot.baseCurrencyCode)
            await MainActor.run { netWorthStore.reload() }
        }
    }

    private func formatCurrency(_ value: Decimal, code: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        return formatter.string(from: value as NSNumber) ?? "--"
    }

    private func deleteAsset(at offsets: IndexSet) {
        offsets.map { assets[$0] }.forEach(context.delete)
        try? context.save()
        netWorthStore.reload()
    }

    private func deleteReceivable(at offsets: IndexSet) {
        offsets.map { receivables[$0] }.forEach(context.delete)
        try? context.save()
        netWorthStore.reload()
    }

    private func deleteLiability(at offsets: IndexSet) {
        offsets.map { liabilities[$0] }.forEach(context.delete)
        try? context.save()
        netWorthStore.reload()
    }

    private func deleteInvestment(at offsets: IndexSet) {
        offsets.map { investments[$0] }.forEach(context.delete)
        try? context.save()
        netWorthStore.reload()
    }

    private func formattedIdentifier(for entry: ManualInvestmentInput) -> String {
        switch entry.kind {
        case .crypto:
            return entry.coinID.lowercased()
        case .stock:
            return entry.coinID.uppercased()
        }
    }

    private func investmentRow(for asset: ManualAsset) -> some View {
        let summary = investmentSummary(for: asset)
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(summary.title)
                    .font(.headline)
                Spacer()
                Text(formatCurrency(summary.currentValue, code: summary.currencyCode))
            }
            HStack {
                Text("Cost: \(formatCurrency(summary.costBasis, code: summary.currencyCode))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(summary.profitString)
                    .font(.caption.bold())
                    .foregroundColor(summary.profit >= 0 ? .green : .red)
            }
            if let updated = summary.updatedText {
                Text(updated)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func investmentSummary(for asset: ManualAsset) -> InvestmentSummary {
        let currency = appSettingsStore.snapshot.baseCurrencyCode
        let quantity = asset.investmentQuantity as Decimal? ?? .zero
        let costPerUnit = asset.investmentCostPerUnit as Decimal? ?? .zero
        let currentPrice = asset.marketPrice as Decimal? ?? costPerUnit
        let costBasis = quantity * costPerUnit
        let currentValue = quantity * currentPrice
        let profit = currentValue - costBasis
        let titleComponents = [asset.investmentSymbol?.uppercased(), asset.name].compactMap { $0 }.filter { !$0.isEmpty }
        let title = titleComponents.isEmpty ? (asset.name ?? "Investment") : titleComponents.joined(separator: " • ")
        return InvestmentSummary(
            title: title,
            currentValue: currentValue,
            costBasis: costBasis,
            profit: profit,
            updatedAt: asset.marketPriceUpdatedAt,
            currencyCode: currency
        )
    }
}

private struct InvestmentSummary {
    let title: String
    let currentValue: Decimal
    let costBasis: Decimal
    let profit: Decimal
    let updatedAt: Date?
    let currencyCode: String

    var profitString: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        let formatted = formatter.string(from: profit as NSNumber) ?? "--"
        return profit >= 0 ? "+" + formatted : formatted
    }

    var updatedText: String? {
        guard let updatedAt else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return "Updated " + formatter.localizedString(for: updatedAt, relativeTo: Date())
    }
}

struct ManualInvestmentInput {
    enum Kind: String, CaseIterable, Identifiable {
        case crypto
        case stock

        var id: String { rawValue }
        var title: String {
            switch self {
            case .crypto: return "Crypto"
            case .stock: return "Stock"
            }
        }
    }

    var kind: Kind
    var name: String
    var coinID: String
    var symbol: String
    var quantity: Decimal
    var costPerUnit: Decimal
    var currencyCode: String

    init(
        kind: Kind = .crypto,
        name: String = "",
        coinID: String = "",
        symbol: String = "",
        quantity: Decimal = .zero,
        costPerUnit: Decimal = .zero,
        currencyCode: String
    ) {
        self.kind = kind
        self.name = name
        self.coinID = coinID
        self.symbol = symbol
        self.quantity = quantity
        self.costPerUnit = costPerUnit
        self.currencyCode = currencyCode
    }
}

struct InvestmentEntryFormView: View {
    let title: String
    let baseCurrencyCode: String
    let onSave: (ManualInvestmentInput) -> Void
    let onDelete: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var input: ManualInvestmentInput

    init(title: String, baseCurrencyCode: String, entry: ManualInvestmentInput? = nil, onSave: @escaping (ManualInvestmentInput) -> Void, onDelete: (() -> Void)? = nil) {
        self.title = title
        self.baseCurrencyCode = baseCurrencyCode
        self.onSave = onSave
        self.onDelete = onDelete
        _input = State(initialValue: entry ?? ManualInvestmentInput(currencyCode: baseCurrencyCode))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Investment Details") {
                    Picker("Type", selection: $input.kind) {
                        ForEach(ManualInvestmentInput.Kind.allCases) { kind in
                            Text(kind.title).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)
                    TextField("Name", text: $input.name)
                    if input.kind == .crypto {
                        TextField("CoinGecko ID", text: $input.coinID)
                            .autocapitalization(.none)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    } else {
                        StockTickerSearchField(ticker: $input.coinID) { suggestion in
                            if input.symbol.isEmpty {
                                input.symbol = suggestion.ticker.uppercased()
                            }
                            if input.name.isEmpty, let name = suggestion.name {
                                input.name = name
                            }
                        }
                    }
                    TextField("Display Symbol", text: $input.symbol)
                        .autocapitalization(.allCharacters)
                    DecimalTextField(title: "Units Held", value: $input.quantity)
                    DecimalTextField(title: "Cost per Unit", value: $input.costPerUnit)
                    NavigationLink {
                        CurrencyPickerView(selectedCode: $input.currencyCode)
                            .navigationTitle("Select Currency")
                    } label: {
                        HStack {
                            Text("Currency")
                            Spacer()
                            Text(input.currencyCode)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Text(input.kind == .crypto ? "Enter the exact CoinGecko coin ID (e.g., bitcoin, ethereum). Prices refresh in your base currency." : "Enter the stock ticker exactly as Massive API expects (e.g., AAPL). Prices refresh in your base currency.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let onDelete {
                    Section {
                        Button(role: .destructive) {
                            onDelete()
                            dismiss()
                        } label: {
                            Text("Delete Investment")
                        }
                    }
                }
            }
            .navigationTitle(title)
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
        !input.name.isEmpty && !input.coinID.isEmpty && input.quantity > 0 && input.costPerUnit > 0
    }

    private func save() {
        onSave(input)
        dismiss()
    }
}

struct StockTickerSearchField: View {
    @Binding var ticker: String
    var onSelect: (MassiveClient.TickerSearchResult) -> Void

    @StateObject private var viewModel = StockSearchViewModel()
    @State private var suppressNextQueryUpdate = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Ticker", text: $ticker)
                .autocapitalization(.allCharacters)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .onChange(of: ticker) { newValue in
                    guard !suppressNextQueryUpdate else {
                        suppressNextQueryUpdate = false
                        return
                    }
                    viewModel.updateQuery(newValue)
                }

            if viewModel.isLoading {
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.7, anchor: .center)
                    Text("Searching tickers…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let message = viewModel.errorMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            if !viewModel.results.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Matches")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach(viewModel.results.indices, id: \.self) { index in
                        let suggestion = viewModel.results[index]
                        Button(action: { select(suggestion) }) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(suggestion.ticker.uppercased())
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(.primary)
                                if let name = suggestion.name {
                                    Text(name)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                if let exchange = suggestion.exchangeDisplay {
                                    Text(exchange)
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)
                        if index < viewModel.results.count - 1 {
                            Divider()
                        }
                    }
                }
                .padding(12)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .onAppear {
            viewModel.updateQuery(ticker)
        }
        .onDisappear {
            viewModel.clear()
        }
    }

    private func select(_ suggestion: MassiveClient.TickerSearchResult) {
        suppressNextQueryUpdate = true
        ticker = suggestion.ticker.uppercased()
        onSelect(suggestion)
        viewModel.clear()
    }
}
