import SwiftUI

struct GoalDetailView: View {
    let goal: SavingGoalModel

    var body: some View {
        Form {
            Section("Progress") {
                ProgressView(value: min(max((goal.progress as NSDecimalNumber).doubleValue / 100, 0), 1))
                Text("\(formatCurrency(goal.currentAmount, code: goal.currencyCode)) / \(formatCurrency(goal.targetAmount, code: goal.currencyCode))")
            }
            if let deadline = goal.deadline {
                Section("Deadline") {
                    Text(deadline, style: .date)
                }
            }
            Section("Status") {
                Text(goal.status.capitalized)
            }
        }
        .navigationTitle(goal.name)
    }

    private func formatCurrency(_ value: Decimal, code: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        return formatter.string(from: value as NSNumber) ?? "--"
    }
}
