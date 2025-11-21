import SwiftUI
import SwiftUI
import CoreData

struct SellHoldingForm: View {
    let lot: HoldingLotModel
    let onSave: (SellHoldingInput) -> Void
    @EnvironmentObject private var walletsStore: WalletsStore
    @Environment(\.dismiss) private var dismiss
    @State private var input: SellHoldingInput

    init(lot: HoldingLotModel, onSave: @escaping (SellHoldingInput) -> Void) {
        self.lot = lot
        self.onSave = onSave
        _input = State(initialValue: SellHoldingInput(quantity: lot.quantity, price: lot.latestPrice ?? lot.costPerUnit))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Sale Details") {
                    DecimalTextField(title: "Quantity", value: $input.quantity)
                    Text("Available: \(lot.quantity as NSDecimalNumber)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    DecimalTextField(title: "Sale Price", value: $input.price)
                }
                Section("Destination Wallet") {
                    Picker("Wallet", selection: $input.walletID) {
                        ForEach(walletsStore.wallets) { wallet in
                            Text(wallet.name).tag(Optional(wallet.id))
                        }
                    }
                }
            }
            .navigationTitle("Sell Holding")
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
        input.walletID != nil && input.quantity > 0 && input.price > 0 && input.quantity <= lot.quantity
    }

    private func save() {
        onSave(input)
        dismiss()
    }
}

struct SellHoldingInput {
    var quantity: Decimal
    var price: Decimal
    var walletID: NSManagedObjectID?
}
