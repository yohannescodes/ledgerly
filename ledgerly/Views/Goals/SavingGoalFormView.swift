import SwiftUI
import CoreData

struct SavingGoalFormInput {
    var categoryID: NSManagedObjectID?
    var name: String = ""
    var targetAmount: Decimal = .zero
    var walletID: NSManagedObjectID?
    var currencyCode: String = Locale.current.currency?.identifier ?? "USD"
    var deadline: Date = Calendar.current.date(byAdding: .month, value: 6, to: Date()) ?? Date()
}

struct SavingGoalFormView: View {
    @Environment(\.managedObjectContext) private var context
    @FetchRequest(sortDescriptors: [SortDescriptor(\.name, order: .forward)])
    private var categories: FetchedResults<Category>
    let wallets: [WalletModel]
    let onSave: (SavingGoalFormInput) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var input = SavingGoalFormInput()

    var body: some View {
        NavigationStack {
            Form {
                Section("Goal Details") {
                    TextField("Name", text: $input.name)
                    DecimalTextField(title: "Target Amount", value: $input.targetAmount)
                    NavigationLink {
                        CurrencyPickerView(
                            selectedCode: $input.currencyCode,
                            infoText: "Money you are saving toward this goal"
                        )
                        .navigationTitle("Select Currency")
                    } label: {
                        HStack {
                            Text("Currency")
                            Spacer()
                            Text(currencyDisplay)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Timeline") {
                    DatePicker(
                        "Deadline",
                        selection: $input.deadline,
                        in: Date()...,
                        displayedComponents: .date
                    )
                }

                Section("Tracking") {
                    Picker("Wallet", selection: $input.walletID) {
                        Text("None").tag(Optional<NSManagedObjectID>(nil))
                        ForEach(wallets) { wallet in
                            Text(wallet.name).tag(Optional(wallet.id))
                        }
                    }
                    Picker("Category", selection: $input.categoryID) {
                        Text("None").tag(Optional<NSManagedObjectID>(nil))
                        ForEach(categories) { category in
                            Text(category.name ?? "Category").tag(Optional(category.objectID))
                        }
                    }
                }
            }
            .navigationTitle("New Goal")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: dismiss.callAsFunction) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!canSave)
                }
            }
        }
}

    private var currencyDisplay: String {
        let code = input.currencyCode
        let option = CurrencyDataSource.all.first { $0.code == code }
        return option.map { "\($0.code) • \($0.name)" } ?? code
    }

    private var canSave: Bool {
        !input.name.isEmpty && input.targetAmount > 0
    }

    private func save() {
        onSave(input)
        dismiss()
    }
}
