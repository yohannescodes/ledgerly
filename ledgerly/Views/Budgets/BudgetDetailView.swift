import SwiftUI

struct BudgetDetailView: View {
    let budget: MonthlyBudgetModel
    let onEdit: () -> Void
    let onDelete: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteConfirm = false

    var body: some View {
        Form {
            Section("Category") {
                Text(budget.categoryName)
            }
            Section("Limit") {
                Text(formatCurrency(budget.limitAmount, code: budget.currencyCode))
                Text("Spent: \(formatCurrency(budget.spentAmount, code: budget.currencyCode))")
                    .foregroundStyle(.secondary)
                ProgressView(value: progress)
            }
            Section {
                Button("Edit", action: onEdit)
            }
            Section {
                Button("Delete Budget", role: .destructive) {
                    showingDeleteConfirm = true
                }
            }
        }
        .navigationTitle("Budget Detail")
        .confirmationDialog(
            "Delete this budget?",
            isPresented: $showingDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete Budget", role: .destructive) {
                onDelete()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var progress: Double {
        guard budget.limitAmount > 0 else { return 0 }
        let ratio = (budget.spentAmount / budget.limitAmount) as NSDecimalNumber
        return min(max(ratio.doubleValue, 0), 1)
    }

    private func formatCurrency(_ value: Decimal, code: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        return formatter.string(from: value as NSNumber) ?? "--"
    }
}
