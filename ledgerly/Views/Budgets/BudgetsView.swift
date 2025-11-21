import SwiftUI

struct BudgetsView: View {
    @EnvironmentObject private var budgetsStore: BudgetsStore

    var body: some View {
        List(budgetsStore.budgets) { budget in
            VStack(alignment: .leading, spacing: 8) {
                Text(budget.categoryName)
                    .font(.headline)
                ProgressView(value: progress(for: budget))
                Text("Spent \(formatCurrency(budget.spentAmount, code: budget.currencyCode)) / \(formatCurrency(budget.limitAmount, code: budget.currencyCode))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Budgets")
        .onAppear { budgetsStore.reload() }
    }

    private func progress(for budget: MonthlyBudgetModel) -> Double {
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
