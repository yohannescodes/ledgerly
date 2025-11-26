import SwiftUI

struct GoalsSummaryCard: View {
    @EnvironmentObject private var goalsStore: GoalsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Goals")
                .font(.headline)
            ForEach(goalsStore.goals.sorted { ($0.deadline ?? .distantFuture) < ($1.deadline ?? .distantFuture) }.prefix(3)) { goal in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(goal.name)
                        Spacer()
                        Text("\(goal.progressPercentage)%")
                    }
                    ProgressView(value: goal.progressFraction)
                    if let deadline = goal.deadline {
                        Text("Due in \(daysRemaining(until: deadline)) days")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
        .onAppear { goalsStore.reload() }
    }
}

    private func daysRemaining(until date: Date) -> Int {
        max(Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 0, 0)
    }
