import SwiftUI

struct GoalsView: View {
    @EnvironmentObject private var goalsStore: GoalsStore

    var body: some View {
        List(goalsStore.goals) { goal in
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
        .navigationTitle("Goals")
        .onAppear { goalsStore.reload() }
    }

    private func formatCurrency(_ value: Decimal, code: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        return formatter.string(from: value as NSNumber) ?? "--"
    }
}
