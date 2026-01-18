import SwiftUI

struct BudgetsView: View {
    @EnvironmentObject private var budgetsStore: BudgetsStore
    @State private var showingForm = false
    @State private var editingBudget: MonthlyBudgetModel? = nil

    var body: some View {
        List {
            if budgetsStore.budgets.isEmpty {
                Section {
                    ContentUnavailableView(
                        label: {
                            Label("No budgets yet", systemImage: "chart.pie.fill")
                                .font(.title3.bold())
                        },
                        description: {
                            Text("Create monthly limits for your top categories and Ledgerly will track progress automatically.")
                        },
                        actions: {
                            Button(action: presentNewBudget) {
                                Label("Add Budget", systemImage: "plus")
                            }
                        }
                    )
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            } else {
                ForEach(budgetsStore.budgets) { budget in
                    NavigationLink(destination: BudgetDetailView(budget: budget, onEdit: {
                        presentEditBudget(budget)
                    }, onDelete: {
                        budgetsStore.deleteBudget(budgetID: budget.id)
                    })) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(budget.categoryName)
                                .font(.headline)
                            ProgressView(value: progress(for: budget))
                            Text("Spent \(formatCurrency(budget.spentAmount, code: budget.currencyCode)) / \(formatCurrency(budget.limitAmount, code: budget.currencyCode))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete(perform: deleteBudgets)
            }
        }
        .navigationTitle("Budgets")
        .toolbar {
            Button(action: presentNewBudget) {
                Image(systemName: "plus")
            }
        }
        .sheet(isPresented: $showingForm, onDismiss: { editingBudget = nil }) {
            BudgetFormView(existingBudget: editingBudget) { input in
                if let existing = input.existingBudgetID {
                    budgetsStore.updateBudget(budgetID: existing, input: input)
                } else {
                    budgetsStore.createBudget(input: input)
                }
            }
        }
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

    private func deleteBudgets(at offsets: IndexSet) {
        let budgets = budgetsStore.budgets
        offsets.map { budgets[$0] }.forEach { budget in
            budgetsStore.deleteBudget(budgetID: budget.id)
        }
    }

    private func presentNewBudget() {
        editingBudget = nil
        showingForm = true
    }

    private func presentEditBudget(_ budget: MonthlyBudgetModel) {
        editingBudget = budget
        showingForm = true
    }
}
