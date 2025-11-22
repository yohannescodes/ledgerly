import SwiftUI

struct TransactionsView: View {
    @EnvironmentObject private var walletsStore: WalletsStore
    @EnvironmentObject private var appSettingsStore: AppSettingsStore
    @StateObject private var viewModel: TransactionsViewModel
    @State private var showingFilterSheet = false
    @State private var showingCreateSheet = false
    @State private var selectedTransaction: TransactionModel?

    init(store: TransactionsStore) {
        _viewModel = StateObject(wrappedValue: TransactionsViewModel(store: store))
    }

    var body: some View {
        VStack(spacing: 0) {
            summaryHeader
            segmentedControl
            if viewModel.sections.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(viewModel.sections) { section in
                        Section(header: sectionHeader(for: section)) {
                            ForEach(section.transactions) { transaction in
                                TransactionRow(model: transaction)
                                    .contentShape(Rectangle())
                                    .onTapGesture { selectedTransaction = transaction }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Transactions")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { showingFilterSheet = true }) {
                    Label("Filters", systemImage: "line.3.horizontal.decrease.circle")
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingCreateSheet = true }) {
                    Label("Add", systemImage: "plus.circle")
                }
            }
        }
        .sheet(isPresented: $showingFilterSheet) {
            TransactionsFilterSheet(filter: viewModel.filter, wallets: walletsStore.wallets) { updated in
                viewModel.apply(filter: updated)
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showingCreateSheet) {
            NavigationStack {
                TransactionFormView(wallets: walletsStore.wallets) { input in
                    viewModel.createTransaction(input: input)
                }
            }
        }
        .sheet(item: $selectedTransaction) { transaction in
            NavigationStack {
                TransactionDetailView(model: transaction) { action in
                    viewModel.handle(action: action, for: transaction)
                }
            }
        }
        .onAppear { viewModel.refresh() }
    }

    private var segmentedControl: some View {
        Picker("Segment", selection: Binding(get: { viewModel.filter.segment }, set: { viewModel.updateSegment($0) })) {
            ForEach(TransactionFilter.Segment.allCases) { segment in
                Text(segment.title).tag(segment)
            }
        }
        .pickerStyle(.segmented)
        .padding([.horizontal, .bottom])
    }

    private var summaryHeader: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                SummaryTile(title: "This Month", amount: viewModel.currentMonthTotal, color: .blue)
                SummaryTile(title: "Last Month", amount: viewModel.previousMonthTotal, color: .gray)
                SummaryTile(title: "Income", amount: viewModel.currentIncomeTotal, color: .green)
                SummaryTile(title: "Expenses", amount: viewModel.currentExpenseTotal, color: .red)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    private func sectionHeader(for section: TransactionSection) -> some View {
        HStack {
            Text(section.date, style: .date)
            Spacer()
            Text(section.total as NSNumber, formatter: currencyFormatter)
                .font(.subheadline)
                .foregroundStyle(section.total >= 0 ? .green : .red)
        }
    }

    private var currencyFormatter: NumberFormatter {
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
                .font(.title3).fontWeight(.semibold)
            Text("Tap Add to log your first income or expense.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct SummaryTile: View {
    let title: String
    let amount: Decimal
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(format(amount))
                .font(.headline)
        }
        .padding()
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
    }

    private func format(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = Locale.current.currency?.identifier ?? "USD"
        return formatter.string(from: value as NSNumber) ?? "--"
    }
}
