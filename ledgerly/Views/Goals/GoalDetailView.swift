import SwiftUI

struct GoalDetailView: View {
    let goal: SavingGoalModel

    @EnvironmentObject private var goalsStore: GoalsStore
    @State private var showingContributionSheet = false
    @State private var showingDeleteConfirmation = false

    private var currentGoal: SavingGoalModel {
        goalsStore.goals.first(where: { $0.id == goal.id }) ?? goal
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                progressSection
                metricsSection
                if let deadline = currentGoal.deadline {
                    timelineSection(deadline: deadline)
                }
                actionSection
            }
            .padding()
        }
        .navigationTitle(currentGoal.name)
        .toolbar {
            Menu {
                if currentGoal.status.lowercased() == "completed" {
                    Button("Reopen Goal", systemImage: "arrow.counterclockwise") {
                        goalsStore.reopenGoal(goalID: currentGoal.id)
                    }
                } else {
                    Button("Mark Complete", systemImage: "checkmark.circle") {
                        goalsStore.markGoalCompleted(goalID: currentGoal.id)
                    }
                }

                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    Label("Delete Goal", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
        .sheet(isPresented: $showingContributionSheet) {
            GoalContributionSheet(goal: currentGoal) { delta in
                goalsStore.recordContribution(goalID: currentGoal.id, amountDelta: delta)
            }
        }
        .confirmationDialog("Delete Goal?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                goalsStore.deleteGoal(goalID: currentGoal.id)
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This removes the goal and its history.")
        }
    }

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Progress")
                .font(.headline)
            HStack(alignment: .firstTextBaseline) {
                Text("\(progressPercentage)%")
                    .font(.system(size: 42, weight: .bold))
                Spacer()
                VStack(alignment: .trailing) {
                    Text("Saved")
                        .foregroundStyle(.secondary)
                    Text(formatCurrency(currentGoal.currentAmount, code: currentGoal.currencyCode))
                }
                VStack(alignment: .trailing) {
                    Text("Target")
                        .foregroundStyle(.secondary)
                    Text(formatCurrency(currentGoal.targetAmount, code: currentGoal.currencyCode))
                }
            }
            ProgressView(value: clampedProgress)
                .tint(currentGoal.status.lowercased() == "completed" ? .green : .accentColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
    }

    private var metricsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Metrics")
                .font(.headline)
            metricRow(title: "Remaining", value: formatCurrency(remainingAmount, code: currentGoal.currencyCode))
            if let monthly = recommendedMonthlyContribution {
                metricRow(title: "Needed per month", value: formatCurrency(monthly, code: currentGoal.currencyCode))
            }
            metricRow(title: "Status", value: currentGoal.status.capitalized)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
    }

    private func timelineSection(deadline: Date) -> some View {
        let days = Calendar.current.dateComponents([.day], from: Date(), to: deadline).day ?? 0
        return VStack(alignment: .leading, spacing: 12) {
            Text("Timeline")
                .font(.headline)
            HStack {
                Text("Deadline")
                Spacer()
                Text(deadline, style: .date)
            }
            if days > 0 {
                Text("\(days) days to go")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("This goal is past due. Keep pushing!")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
    }

    private var actionSection: some View {
        VStack(spacing: 12) {
            Button {
                showingContributionSheet = true
            } label: {
                Label("Update Progress", systemImage: "plus.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            if currentGoal.status.lowercased() != "completed" {
                Button {
                    goalsStore.markGoalCompleted(goalID: currentGoal.id)
                } label: {
                    Label("Mark Complete", systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var remainingAmount: Decimal {
        max(currentGoal.targetAmount - currentGoal.currentAmount, 0)
    }

    private var progressPercentage: Int {
        Int(clampedProgress * 100)
    }

    private var clampedProgress: Double {
        let target = NSDecimalNumber(decimal: currentGoal.targetAmount)
        guard target != .zero else { return 0 }
        let current = NSDecimalNumber(decimal: currentGoal.currentAmount)
        let ratio = current.dividing(by: target).doubleValue
        return min(max(ratio, 0), 1)
    }

    private var recommendedMonthlyContribution: Decimal? {
        guard let deadline = currentGoal.deadline else { return nil }
        let components = Calendar.current.dateComponents([.month], from: Date(), to: deadline)
        guard let months = components.month, months > 0 else { return nil }
        let total = NSDecimalNumber(decimal: remainingAmount)
        let divisor = NSDecimalNumber(value: months)
        guard divisor != .zero else { return nil }
        return total.dividing(by: divisor).decimalValue
    }

    private func metricRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
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
