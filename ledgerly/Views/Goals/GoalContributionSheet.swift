import SwiftUI

struct GoalContributionSheet: View {
    enum Mode: String, CaseIterable, Identifiable {
        case add
        case withdraw

        var id: String { rawValue }
        var title: String {
            switch self {
            case .add: return "Add Savings"
            case .withdraw: return "Withdraw"
            }
        }

        var systemImage: String {
            switch self {
            case .add: return "plus.circle"
            case .withdraw: return "arrow.down.circle"
            }
        }
    }

    let goal: SavingGoalModel
    let onSave: (Decimal) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var amount: Decimal = .zero
    @State private var mode: Mode = .add

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Amount")) {
                    DecimalTextField(title: "Amount", value: $amount)
                    Picker("Action", selection: $mode) {
                        ForEach(Mode.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    Text(helperText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Goal Snapshot") {
                    HStack {
                        Text("Saved")
                        Spacer()
                        Text(formatCurrency(goal.currentAmount, code: goal.currencyCode))
                    }
                    HStack {
                        Text("Target")
                        Spacer()
                        Text(formatCurrency(goal.targetAmount, code: goal.currencyCode))
                    }
                }
            }
            .navigationTitle("Update \(goal.name)")
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
        amount > 0
    }

    private var helperText: String {
        switch mode {
        case .add:
            return "Log money you just set aside for this goal."
        case .withdraw:
            return "Reduce progress if you pulled money out."
        }
    }

    private func save() {
        let delta = mode == .add ? amount : -amount
        onSave(delta)
        dismiss()
    }

    private func formatCurrency(_ value: Decimal, code: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        return formatter.string(from: value as NSNumber) ?? "--"
    }
}
