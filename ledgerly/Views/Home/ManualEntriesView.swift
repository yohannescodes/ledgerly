import SwiftUI
import CoreData

struct ManualEntriesView: View {
    @Environment(\.managedObjectContext) private var context
    @EnvironmentObject private var netWorthStore: NetWorthStore

    @FetchRequest(sortDescriptors: [SortDescriptor(\.valuationDate, order: .reverse)])
    private var assets: FetchedResults<ManualAsset>

    @FetchRequest(sortDescriptors: [SortDescriptor(\.dueDate, order: .reverse)])
    private var liabilities: FetchedResults<ManualLiability>

    @State private var showingAssetForm = false
    @State private var showingLiabilityForm = false
    @State private var assetToEdit: ManualAsset?
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
            ManualEntryForm(title: "New Asset", initialName: "", initialValue: .zero) { name, value in
                ManualAsset.create(in: context, name: name, type: "tangible", value: value, currencyCode: Locale.current.currency?.identifier ?? "USD")
                try? context.save()
                netWorthStore.reload()
            }
        }
        .sheet(isPresented: $showingLiabilityForm) {
            ManualEntryForm(title: "New Liability", initialName: "", initialValue: .zero) { name, value in
                ManualLiability.create(in: context, name: name, type: "loan", balance: value, currencyCode: Locale.current.currency?.identifier ?? "USD")
                try? context.save()
                netWorthStore.reload()
            }
        }
        .sheet(isPresented: Binding(get: { assetToEdit != nil }, set: { if !$0 { assetToEdit = nil } })) {
            if let asset = assetToEdit {
                ManualEntryForm(title: "Edit Asset", initialName: asset.name ?? "", initialValue: asset.value as Decimal? ?? .zero) { name, value in
                    asset.name = name
                    asset.value = NSDecimalNumber(decimal: value)
                    try? context.save()
                    netWorthStore.reload()
                    assetToEdit = nil
                }
            }
        }
        .sheet(isPresented: Binding(get: { liabilityToEdit != nil }, set: { if !$0 { liabilityToEdit = nil } })) {
            if let liability = liabilityToEdit {
                ManualEntryForm(title: "Edit Liability", initialName: liability.name ?? "", initialValue: liability.balance as Decimal? ?? .zero) { name, value in
                    liability.name = name
                    liability.balance = NSDecimalNumber(decimal: value)
                    try? context.save()
                    netWorthStore.reload()
                    liabilityToEdit = nil
                }
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

    private func deleteLiability(at offsets: IndexSet) {
        offsets.map { liabilities[$0] }.forEach(context.delete)
        try? context.save()
        netWorthStore.reload()
    }
}

private struct ManualEntryForm: View {
    let title: String
    let initialName: String
    let initialValue: Decimal
    let onSave: (String, Decimal) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var amountText: String

    init(title: String, initialName: String, initialValue: Decimal, onSave: @escaping (String, Decimal) -> Void) {
        self.title = title
        self.initialName = initialName
        self.initialValue = initialValue
        self.onSave = onSave
        _name = State(initialValue: initialName)
        _amountText = State(initialValue: initialValue == .zero ? "" : NSDecimalNumber(decimal: initialValue).stringValue)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                TextField("Amount", text: $amountText)
                    .keyboardType(.decimalPad)
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: dismiss.callAsFunction) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!canSave)
                }
            }
        }
    }

    private var canSave: Bool {
        !name.isEmpty && Decimal(string: amountText) != nil
    }

    private func save() {
        guard let value = Decimal(string: amountText) else { return }
        onSave(name, value)
        dismiss()
    }
}
