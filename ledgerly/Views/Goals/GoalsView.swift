import SwiftUI

struct GoalsView: View {
    @EnvironmentObject private var goalsStore: GoalsStore
    @EnvironmentObject private var walletsStore: WalletsStore
    @State private var showingForm = false

    var body: some View {
        List(goalsStore.goals) { goal in
            NavigationLink(destination: GoalDetailView(goal: goal)) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(goal.name)
                        .font(.headline)
                    ProgressView(value: min(max((goal.progress as NSDecimalNumber).doubleValue / 100, 0), 1))
                    Text("\(formatCurrency(goal.currentAmount, code: goal.currencyCode)) / \(formatCurrency(goal.targetAmount, code: goal.currencyCode))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let deadline = goal.deadline {
                        Text("Due: \(deadline, style: .date)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Goals")
        .toolbar {
            Button(action: { showingForm = true }) {
                Image(systemName: "plus")
            }
        }
        .sheet(isPresented: $showingForm) {
            SavingGoalFormView(wallets: walletsStore.wallets) { input in
                goalsStore.createGoal(input: input)
            }
        }
        .onAppear { goalsStore.reload() }
    }

    private func formatCurrency(_ value: Decimal, code: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        return formatter.string(from: value as NSNumber) ?? "--"
    }
}
