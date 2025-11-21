import SwiftUI

struct MainTabView: View {
    let transactionsStore: TransactionsStore
    let investmentsStore: InvestmentsStore

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
                SettingsDebugView()
                    .navigationTitle("Settings")
            }
            .tabItem {
                Label("Settings", systemImage: "gear")
            }
        }
    }
}
