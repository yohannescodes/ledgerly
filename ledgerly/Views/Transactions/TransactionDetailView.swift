import SwiftUI

struct TransactionDetailView: View {
    let model: TransactionModel
    let onAction: (TransactionDetailAction) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section("Summary") {
                detailRow(label: "Type", value: model.direction.capitalized)
                detailRow(label: "Amount", value: formatCurrency(model.amount, code: model.currencyCode))
                detailRow(label: "Wallet", value: model.walletName)
                detailRow(label: "Date", value: model.date.formatted(date: .abbreviated, time: .shortened))
            }
            if let notes = model.notes, !notes.isEmpty {
                Section("Notes") {
                    Text(notes)
                }
            }
        }
        .navigationTitle("Transaction")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(role: .destructive) {
                        onAction(.delete)
                        dismiss()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }

    private func formatCurrency(_ value: Decimal, code: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        return formatter.string(from: value as NSNumber) ?? "--"
    }
}
