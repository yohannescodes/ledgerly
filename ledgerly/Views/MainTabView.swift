import SwiftUI

struct MainTabView: View {
    let transactionsStore: TransactionsStore
    let investmentsStore: InvestmentsStore
    let budgetsStore: BudgetsStore
    let goalsStore: GoalsStore

    var body: some View {
        TabView {
            NavigationStack {
                HomeOverviewView()
                    .navigationTitle("Home")
            }
            .tabItem {
                Label("Home", systemImage: "house")
            }

            NavigationStack {
                TransactionsView(store: transactionsStore)
                    .navigationTitle("Transactions")
            }
            .tabItem {
                Label("Transactions", systemImage: "list.bullet.rectangle")
            }

            NavigationStack {
                InvestmentsView()
                    .environmentObject(investmentsStore)
            }
            .tabItem {
                Label("Investments", systemImage: "chart.line.uptrend.xyaxis")
            }

            NavigationStack {
                BudgetsView()
                    .environmentObject(budgetsStore)
            }
            .tabItem {
                Label("Budgets", systemImage: "chart.pie.fill")
            }

            NavigationStack {
                GoalsView()
                    .environmentObject(goalsStore)
            }
            .tabItem {
                Label("Goals", systemImage: "target")
            }

            NavigationStack {
                SettingsDebugView()
                    .navigationTitle("Settings")
            }
            .tabItem {
                Label("Settings", systemImage: "gear")
            }
        }
    }
}
