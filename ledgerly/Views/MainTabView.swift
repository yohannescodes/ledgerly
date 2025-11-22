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
            }
            .tabItem {
                Label("Home", systemImage: "house")
            }

            NavigationStack {
                WalletsView()
            }
            .tabItem {
                Label("Wallets", systemImage: "wallet.pass")
            }

            NavigationStack {
                TransactionsView(store: transactionsStore)
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
            }
            .tabItem {
                Label("Settings", systemImage: "gear")
            }
        }
    }
}
