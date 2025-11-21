import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            NavigationStack {
                VStack(spacing: 16) {
                    Image(systemName: "chart.pie.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.tint)
                    Text("Ledgerly Home")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Dashboards for wallets, budgets, and investments will live here in later phases.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .navigationTitle("Home")
            }
            .tabItem {
                Label("Home", systemImage: "house")
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
