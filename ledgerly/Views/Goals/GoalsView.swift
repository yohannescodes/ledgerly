import SwiftUI

struct GoalsView: View {
    private enum GoalFilter: String, CaseIterable, Identifiable {
        case active
        case completed
        case all

        var id: String { rawValue }

        var title: String {
            switch self {
            case .active: return "Active"
            case .completed: return "Completed"
            case .all: return "All"
            }
        }

        func matches(status: String) -> Bool {
            switch self {
            case .all: return true
            case .active: return status.lowercased() != "completed"
            case .completed: return status.lowercased() == "completed"
            }
        }
    }

    @EnvironmentObject private var goalsStore: GoalsStore
    @EnvironmentObject private var walletsStore: WalletsStore
    @State private var showingForm = false
    @State private var selectedFilter: GoalFilter = .active
    @State private var contributionGoal: SavingGoalModel?

    var body: some View {
        List {
            Section {
                GoalsOverviewCard(
                    activeCount: activeGoals.count,
                    completedCount: completedGoals.count,
                    averageProgress: averageProgress,
                    upcomingGoal: upcomingGoal
                )
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            if goalsStore.goals.isEmpty {
                Section {
                    ContentUnavailableView(
                        "No goals yet",
                        systemImage: "target",
                        description: Text("Create your first savings goal to keep tabs on progress.")
                    )
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            } else {
                Section {
                    Picker("Filter", selection: $selectedFilter) {
                        ForEach(GoalFilter.allCases) { filter in
                            Text(filter.title).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Goals") {
                    ForEach(filteredGoals) { goal in
                        NavigationLink(destination: GoalDetailView(goal: goal)) {
                            goalRow(for: goal)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button {
                                contributionGoal = goal
                            } label: {
                                Label("Update", systemImage: "plus.circle")
                            }
                            .tint(.blue)

                            if goal.status.lowercased() == "completed" {
                                Button {
                                    goalsStore.reopenGoal(goalID: goal.id)
                                } label: {
                                    Label("Reopen", systemImage: "arrow.counterclockwise")
                                }
                                .tint(.orange)
                            } else {
                                Button {
                                    goalsStore.markGoalCompleted(goalID: goal.id)
                                } label: {
                                    Label("Complete", systemImage: "checkmark.circle")
                                }
                                .tint(.green)
                            }

                            Button(role: .destructive) {
                                goalsStore.deleteGoal(goalID: goal.id)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                    .onDelete(perform: deleteGoals)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Goals")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) { EditButton() }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingForm = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingForm) {
            SavingGoalFormView(wallets: walletsStore.wallets) { input in
                goalsStore.createGoal(input: input)
            }
        }
        .sheet(item: $contributionGoal) { goal in
            GoalContributionSheet(goal: goal) { delta in
                goalsStore.recordContribution(goalID: goal.id, amountDelta: delta)
            }
        }
        .onAppear { goalsStore.reload() }
    }

    private var filteredGoals: [SavingGoalModel] {
        goalsStore.goals
            .filter { selectedFilter.matches(status: $0.status) }
            .sorted { lhs, rhs in
                let leftDate = lhs.deadline ?? .distantFuture
                let rightDate = rhs.deadline ?? .distantFuture
                if leftDate == rightDate {
                    return lhs.name < rhs.name
                }
                return leftDate < rightDate
            }
    }

    private var activeGoals: [SavingGoalModel] {
        goalsStore.goals.filter { $0.status.lowercased() != "completed" }
    }

    private var completedGoals: [SavingGoalModel] {
        goalsStore.goals.filter { $0.status.lowercased() == "completed" }
    }

    private var averageProgress: Double {
        let values = goalsStore.goals.map { min(max((($0.progress as NSDecimalNumber).doubleValue / 100), 0), 1) }
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    private var upcomingGoal: SavingGoalModel? {
        activeGoals
            .filter { $0.deadline != nil }
            .sorted { ($0.deadline ?? .distantFuture) < ($1.deadline ?? .distantFuture) }
            .first
    }

    private func goalRow(for goal: SavingGoalModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(goal.name)
                    .font(.headline)
                Spacer()
                statusBadge(for: goal)
            }
            ProgressView(value: min(max((goal.progress as NSDecimalNumber).doubleValue / 100, 0), 1))
                .tint(goal.status.lowercased() == "completed" ? .green : .accentColor)
            HStack {
                Text("\(formatCurrency(goal.currentAmount, code: goal.currencyCode)) saved")
                Spacer()
                Text("Target: \(formatCurrency(goal.targetAmount, code: goal.currencyCode))")
                    .foregroundStyle(.secondary)
            }
            if let deadline = goal.deadline {
                Text(deadlineText(for: deadline))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func statusBadge(for goal: SavingGoalModel) -> some View {
        Text(goal.status.capitalized)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule().fill(
                    goal.status.lowercased() == "completed"
                    ? Color.green.opacity(0.2)
                    : Color.blue.opacity(0.15)
                )
            )
    }

    private func formatCurrency(_ value: Decimal, code: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        formatter.maximumFractionDigits = 2
        return formatter.string(from: value as NSNumber) ?? "--"
    }

    private func deadlineText(for deadline: Date) -> String {
        let daysRemaining = Calendar.current.dateComponents([.day], from: Date(), to: deadline).day ?? 0
        if daysRemaining <= 0 {
            return "Past due"
        }
        let formattedDate = DateFormatter.short.string(from: deadline)
        return "Due in \(daysRemaining) days (\(formattedDate))"
    }

    private func deleteGoals(at offsets: IndexSet) {
        let goals = offsets.compactMap { index in
            filteredGoals[safe: index]
        }
        goals.forEach { goal in
            goalsStore.deleteGoal(goalID: goal.id)
        }
    }
}

private struct GoalsOverviewCard: View {
    let activeCount: Int
    let completedCount: Int
    let averageProgress: Double
    let upcomingGoal: SavingGoalModel?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Savings Goals")
                        .font(.headline)
                    Text("\(completedCount) of \(activeCount + completedCount) completed")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(Int(averageProgress * 100))% avg")
                    .font(.title3.bold())
            }

            ProgressView(value: averageProgress)

            if let goal = upcomingGoal, let deadline = goal.deadline {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Next Milestone")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(goal.name)
                        .font(.body)
                    Text(deadline, style: .date)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Set a deadline to get friendly reminders.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
    }
}

private extension DateFormatter {
    static let short: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter
    }()
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
