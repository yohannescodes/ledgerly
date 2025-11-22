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
                NetWorthFormulaCard(totals: netWorthStore.liveTotals)
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
            EmptyView()
        case .budgetSummary:
            BudgetSummaryCard()
        case .goalsSummary:
            GoalsSummaryCard()
        case .netWorthHistory:
            NetWorthHistoryCard(snapshots: netWorthStore.displaySnapshots)
        }
    }
}

private struct NetWorthFormulaCard: View {
    let totals: NetWorthTotals?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Financial Health")
                .font(.headline)
            Text("Total Net Worth = (Assets + Investments + Wallets + Receivables) - Liabilities")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let totals {
                Group {
                    formulaRow(title: "Assets", value: totals.manualAssets)
                    VStack(alignment: .leading, spacing: 4) {
                        formulaRow(title: "Investments", value: totals.totalInvestments)
                        HStack {
                            Text("   • Stocks")
                            Spacer()
                            Text(formatCurrency(totals.stockInvestments))
                                .font(.caption)
                        }
                        HStack {
                            Text("   • Crypto")
                            Spacer()
                            Text(formatCurrency(totals.cryptoInvestments))
                                .font(.caption)
                        }
                    }
                    formulaRow(title: "Wallets", value: totals.walletAssets)
                    formulaRow(title: "Receivables", value: totals.receivables)
                }
                Divider()
                formulaRow(title: "Total Assets", value: totals.totalAssets, emphasize: true)
                formulaRow(title: "Liabilities", value: totals.totalLiabilities)
                Divider()
                formulaRow(title: "Net Worth", value: totals.netWorth, emphasize: true)
            } else {
                Text("Add wallets and assets to see the breakdown.")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
    }

    private func formulaRow(title: String, value: Decimal, emphasize: Bool = false) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(formatCurrency(value))
                .fontWeight(emphasize ? .bold : .semibold)
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
