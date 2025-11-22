import SwiftUI

struct HomeOverviewView: View {
    @EnvironmentObject private var netWorthStore: NetWorthStore
    @EnvironmentObject private var appSettingsStore: AppSettingsStore

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if orderedWidgets.isEmpty {
                    Text("Customize your dashboard from Settings → Dashboard.")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()
                } else {
                    ForEach(orderedWidgets) { widget in
                        widgetView(for: widget)
                    }
                }
                NavigationLink("Manage Manual Assets & Liabilities") {
                    ManualEntriesView()
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
        }
        .onAppear { netWorthStore.reload() }
    }

    private var orderedWidgets: [DashboardWidget] {
        appSettingsStore.snapshot.dashboardWidgets
    }

    @ViewBuilder
    private func widgetView(for widget: DashboardWidget) -> some View {
        switch widget {
        case .netWorthSummary:
            NetWorthSummaryCard(totals: netWorthStore.liveTotals)
        case .budgetSummary:
            BudgetSummaryCard()
        case .goalsSummary:
            GoalsSummaryCard()
        case .netWorthHistory:
            NetWorthHistoryCard(snapshots: netWorthStore.snapshots)
        }
    }
}

private struct NetWorthSummaryCard: View {
    let totals: NetWorthTotals?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Net Worth")
                .font(.headline)
            if let totals {
                VStack(alignment: .leading, spacing: 8) {
                    metricRow(title: "Total Assets", value: totals.totalAssets)
                    metricRow(title: "Total Liabilities", value: totals.totalLiabilities)
                    metricRow(title: "Core Net Worth", value: totals.coreNetWorth)
                    metricRow(title: "Tangible Net Worth", value: totals.tangibleNetWorth)
                }
            } else {
                Text("No net worth snapshots yet.")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
    }

    private func metricRow(title: String, value: Decimal) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(formatCurrency(value))
                .fontWeight(.semibold)
        }
    }

    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = Locale.current.currency?.identifier ?? "USD"
        return formatter.string(from: value as NSNumber) ?? "--"
    }
}

#Preview {
    HomeOverviewView()
        .environmentObject(AppSettingsStore(persistence: PersistenceController.preview))
        .environmentObject(NetWorthStore(persistence: PersistenceController.preview))
        .environmentObject(BudgetsStore(persistence: PersistenceController.preview))
        .environmentObject(GoalsStore(persistence: PersistenceController.preview))
}
