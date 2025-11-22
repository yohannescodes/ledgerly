import SwiftUI

struct MainTabView: View {
    let transactionsStore: TransactionsStore
    let investmentsStore: InvestmentsStore
    let budgetsStore: BudgetsStore
    let goalsStore: GoalsStore

    var body: some View {
        TabView {
            NavigationStack { HomeOverviewView() }
                .tabItem { Label("Home", systemImage: "house") }

            NavigationStack { WalletsView() }
                .tabItem { Label("Wallets", systemImage: "wallet.pass") }

            NavigationStack { TransactionsView(store: transactionsStore) }
                .tabItem { Label("Transactions", systemImage: "list.bullet.rectangle") }

            NavigationStack {
                InvestmentsView()
                    .environmentObject(investmentsStore)
            }
            .tabItem { Label("Investments", systemImage: "chart.line.uptrend.xyaxis") }

            NavigationStack {
                MoreHubView()
            }
            .tabItem { Label("More", systemImage: "ellipsis.circle") }
        }
    }
}
