import SwiftUI
import CoreData

struct WalletTransferForm: View {
    let holdingCost: Decimal
    let onSave: (WalletTransferInput) -> Void
    @EnvironmentObject private var walletsStore: WalletsStore
    @Environment(\.dismiss) private var dismiss
    @State private var input = WalletTransferInput()

    var body: some View {
        NavigationStack {
            Form {
                Section("Cash Movement") {
                    Picker("Wallet", selection: $input.walletID) {
                        ForEach(walletsStore.wallets) { wallet in
                            Text(wallet.name).tag(Optional(wallet.id))
                        }
                    }
                    TextField("Amount", text: Binding(
                        get: { input.amountText },
                        set: { newValue in
                            input.amountText = newValue
                            input.amount = Decimal(string: newValue) ?? holdingCost
                        }
                    ))
                    .keyboardType(.decimalPad)
                }
                Section("Notes") {
                    TextField("Note", text: $input.note)
                }
            }
            .navigationTitle("Wallet Transfer")
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
        input.walletID != nil && input.amount > 0
    }

    private func save() {
        onSave(input)
        dismiss()
    }
}

struct WalletTransferInput {
    var walletID: NSManagedObjectID?
    var amount: Decimal = .zero
    var note: String = ""
    var amountText: String = ""
}
