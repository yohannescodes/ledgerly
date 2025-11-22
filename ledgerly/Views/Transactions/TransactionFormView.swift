import SwiftUI
import CoreData

struct TransactionFormView: View {
    let wallets: [WalletModel]
    let onSave: (TransactionFormInput) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var context
    @State private var input = TransactionFormInput()
    @State private var categories: [CategoryModel] = []
    @State private var showingCategoryForm = false

    private var canSave: Bool {
        input.amount > 0 && input.walletID != nil && (input.direction != .transfer || input.destinationWalletID != nil)
    }

    var body: some View {
        Form {
            Section("Type") {
                Picker("Direction", selection: $input.direction) {
                    ForEach(TransactionFormInput.Direction.allCases) { direction in
                        Text(direction.title).tag(direction)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Amount") {
                DecimalTextField(title: "Amount", value: $input.amount)
                NavigationLink {
                    CurrencyPickerView(selectedCode: $input.currencyCode)
                } label: {
                    HStack {
                        Text("Currency")
                        Spacer()
                        Text(input.currencyCode)
                            .foregroundStyle(.secondary)
                    }
                }
                DatePicker("Date", selection: $input.date, displayedComponents: [.date, .hourAndMinute])
            }

            Section("Wallets") {
                Picker("From", selection: Binding(get: { input.walletID }, set: { input.walletID = $0 })) {
                    Text("Select Wallet").tag(Optional<NSManagedObjectID>(nil))
                    ForEach(wallets) { wallet in
                        Text(wallet.name).tag(Optional(wallet.id))
                    }
                }
                if input.direction == .transfer {
                    Picker("To", selection: Binding(get: { input.destinationWalletID }, set: { input.destinationWalletID = $0 })) {
                        Text("Select Wallet").tag(Optional<NSManagedObjectID>(nil))
                        ForEach(wallets) { wallet in
                            Text(wallet.name).tag(Optional(wallet.id))
                        }
                    }
                }
            }

            Section("Notes") {
                TextField("Optional notes", text: $input.notes)
            }

            Section("Category") {
                Picker("Category", selection: Binding(get: { input.categoryID }, set: { input.categoryID = $0 })) {
                    Text("Uncategorized").tag(Optional<NSManagedObjectID>(nil))
                    ForEach(categories) { category in
                        Text(category.name).tag(Optional(category.id))
                    }
                }
                Button("Add Category") { showingCategoryForm = true }
            }
        }
        .navigationTitle("New Transaction")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", action: dismiss.callAsFunction)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    onSave(input)
                    dismiss()
                }
                .disabled(!canSave)
            }
        }
        .onAppear {
            if input.walletID == nil {
                input.walletID = wallets.first?.id
            }
            loadCategories()
        }
        .sheet(isPresented: $showingCategoryForm) {
            CategoryFormView { category in
                categories.append(category)
                input.categoryID = category.id
            }
            .environment(\.managedObjectContext, context)
        }
    }

    private func loadCategories() {
        let request = Category.fetchRequestAll()
        if let result = try? context.fetch(request) {
            categories = result.map(CategoryModel.init)
        }
    }
}
