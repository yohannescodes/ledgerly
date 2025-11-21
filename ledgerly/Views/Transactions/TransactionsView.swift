import SwiftUI

struct TransactionsView: View {
    @EnvironmentObject private var walletsStore: WalletsStore
    @EnvironmentObject private var appSettingsStore: AppSettingsStore
    @StateObject private var viewModel: TransactionsViewModel
    @State private var showingFilterSheet = false
    @State private var showingAddSheet = false

    init(store: TransactionsStore) {
        _viewModel = StateObject(wrappedValue: TransactionsViewModel(store: store))
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Segment", selection: Binding(get: { viewModel.filter.segment }, set: { viewModel.updateSegment($0) })) {
                ForEach(TransactionFilter.Segment.allCases) { segment in
                    Text(segment.title)
                        .tag(segment)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top)

            if viewModel.sections.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(viewModel.sections) { section in
                        Section(header: sectionHeader(for: section)) {
                            ForEach(section.transactions) { transaction in
                                TransactionRow(model: transaction)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Transactions")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingFilterSheet = true }) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingAddSheet = true }) {
                    Image(systemName: "plus.circle.fill")
                }
            }
        }
        .sheet(isPresented: $showingFilterSheet) {
            TransactionsFilterSheet(filter: viewModel.filter)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showingAddSheet) {
            AddTransactionPlaceholderView(wallets: walletsStore.wallets)
                .presentationDetents([.large])
        }
        .onAppear {
            viewModel.refresh()
        }
    }

    private func sectionHeader(for section: TransactionSection) -> some View {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        let title = formatter.string(from: section.date)
        return HStack {
            Text(title)
            Spacer()
            Text(section.total as NSNumber, formatter: numberFormatter)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var numberFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = appSettingsStore.snapshot.baseCurrencyCode
        return formatter
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No transactions yet")
                .font(.title3)
                .fontWeight(.semibold)
            Text("Add your first expense or income to see summaries here.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct TransactionRow: View {
    let model: TransactionModel

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(model.category?.name ?? model.direction.capitalized)
                    .font(.headline)
                Text(model.walletName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(amountText)
                    .font(.headline)
                    .foregroundStyle(model.direction == "expense" ? .red : .green)
                Text(model.currencyCode)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var amountText: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = model.currencyCode
        return formatter.string(from: model.amount as NSNumber) ?? "--"
    }
}

private struct TransactionsFilterSheet: View {
    let filter: TransactionFilter
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Segment") {
                    Picker("Type", selection: .constant(filter.segment)) {
                        ForEach(TransactionFilter.Segment.allCases) { segment in
                            Text(segment.title).tag(segment)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                Section {
                    Text("More filters coming soon")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Filters")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done", action: dismiss.callAsFunction)
                }
            }
        }
    }
}

private struct AddTransactionPlaceholderView: View {
    let wallets: [WalletModel]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Wallet") {
                    if wallets.isEmpty {
                        Text("No wallets available")
                    } else {
                        Text(wallets.first?.name ?? "Wallet")
                    }
                }
                Section("Details") {
                    Text("Transaction form will arrive in the next iteration.")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("New Transaction")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", action: dismiss.callAsFunction)
                }
            }
        }
    }
}

#Preview {
    let persistence = PersistenceController.preview
    let transactionsStore = TransactionsStore(persistence: persistence)
    TransactionsView(store: transactionsStore)
        .environmentObject(AppSettingsStore(persistence: persistence))
        .environmentObject(WalletsStore(persistence: persistence))
}
