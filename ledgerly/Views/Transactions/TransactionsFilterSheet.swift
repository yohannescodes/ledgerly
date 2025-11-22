import SwiftUI
import CoreData

struct TransactionsFilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var workingFilter: TransactionFilter
    @State private var useStartDate: Bool
    @State private var useEndDate: Bool
    let wallets: [WalletModel]
    let onApply: (TransactionFilter) -> Void

    init(filter: TransactionFilter, wallets: [WalletModel], onApply: @escaping (TransactionFilter) -> Void) {
        _workingFilter = State(initialValue: filter)
        _useStartDate = State(initialValue: filter.startDate != nil)
        _useEndDate = State(initialValue: filter.endDate != nil)
        self.wallets = wallets
        self.onApply = onApply
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Segment") {
                    Picker("Type", selection: $workingFilter.segment) {
                        ForEach(TransactionFilter.Segment.allCases) { segment in
                            Text(segment.title).tag(segment)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Wallet") {
                    Picker("Wallet", selection: Binding(get: { workingFilter.walletID }, set: { workingFilter.walletID = $0 })) {
                        Text("All Wallets").tag(Optional<NSManagedObjectID>(nil))
                        ForEach(wallets) { wallet in
                            Text(wallet.name).tag(Optional(wallet.id))
                        }
                    }
                }

                Section("Dates") {
                    Toggle("Filter by start date", isOn: $useStartDate)
                    if useStartDate {
                        DatePicker("Start", selection: Binding(get: { workingFilter.startDate ?? Date() }, set: { workingFilter.startDate = $0 }), displayedComponents: .date)
                    }
                    Toggle("Filter by end date", isOn: $useEndDate)
                    if useEndDate {
                        DatePicker("End", selection: Binding(get: { workingFilter.endDate ?? Date() }, set: { workingFilter.endDate = $0 }), displayedComponents: .date)
                    }
                }

                Section("Search") {
                    TextField("Notes or wallet", text: $workingFilter.searchText)
                }
            }
            .navigationTitle("Filters")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: dismiss.callAsFunction)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        if !useStartDate { workingFilter.startDate = nil }
                        if !useEndDate { workingFilter.endDate = nil }
                        onApply(workingFilter)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .bottomBar) {
                    Button("Reset") {
                        workingFilter = TransactionFilter()
                        useStartDate = false
                        useEndDate = false
                    }
                }
            }
        }
    }
}
