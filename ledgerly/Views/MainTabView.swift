import SwiftUI

struct MainTabView: View {
    let transactionsStore: TransactionsStore

    var body: some View {
        TabView {
            NavigationStack { HomeOverviewView() }
                .tabItem { Label("Home", systemImage: "house") }

            NavigationStack { WalletsView() }
                .tabItem { Label("Wallets", systemImage: "wallet.pass") }

            NavigationStack { TransactionsView(store: transactionsStore) }
                .tabItem { Label("Transactions", systemImage: "list.bullet.rectangle") }

            NavigationStack {
                MoreHubView()
            }
            .tabItem { Label("More", systemImage: "ellipsis.circle") }
        }
    }
}
