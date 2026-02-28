import SwiftUI

struct BudgetSummaryCard: View {
    @EnvironmentObject private var budgetsStore: BudgetsStore
    @EnvironmentObject private var appSettingsStore: AppSettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Budgets")
                .font(.headline)
            ForEach(budgetsStore.budgets.prefix(3)) { budget in
                HStack {
                    Text(budget.categoryName)
                    Spacer()
                    Text(progressText(for: budget))
                }
                ProgressView(value: progress(for: budget))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
        .onAppear { budgetsStore.reload() }
        .onChange(of: appSettingsStore.snapshot) { _ in
            budgetsStore.reload()
        }
    }

    private func progress(for budget: MonthlyBudgetModel) -> Double {
        guard budget.limitAmount > 0 else { return 0 }
        let ratio = (budget.spentAmount / budget.limitAmount) as NSDecimalNumber
        return min(max(ratio.doubleValue, 0), 1)
    }

    private func progressText(for budget: MonthlyBudgetModel) -> String {
        let percent = Int(progress(for: budget) * 100)
        return "\(percent)%"
    }
}
