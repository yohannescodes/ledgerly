import SwiftUI
import CoreData

struct ManualEntriesView: View {
    @Environment(\.managedObjectContext) private var context
    @EnvironmentObject private var netWorthStore: NetWorthStore

    @FetchRequest(
        sortDescriptors: [SortDescriptor(\.valuationDate, order: .reverse)],
        predicate: NSPredicate(format: "NOT (type CONTAINS[cd] %@)", "receiv")
    )
    private var assets: FetchedResults<ManualAsset>

    @FetchRequest(
        sortDescriptors: [SortDescriptor(\.valuationDate, order: .reverse)],
        predicate: NSPredicate(format: "type CONTAINS[cd] %@", "receiv")
    )
    private var receivables: FetchedResults<ManualAsset>

    @FetchRequest(sortDescriptors: [SortDescriptor(\.dueDate, order: .reverse)])
    private var liabilities: FetchedResults<ManualLiability>

    @State private var showingAssetForm = false
    @State private var showingReceivableForm = false
    @State private var showingLiabilityForm = false
    @State private var assetToEdit: ManualAsset?
    @State private var receivableToEdit: ManualAsset?
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
}

// Legacy ManualEntryForm removed (replaced by ManualEntryFormView)
