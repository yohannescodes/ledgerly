import SwiftUI

struct MoreHubView: View {
    var body: some View {
        List {
            Section("Planning") {
                NavigationLink(destination: BudgetsView()) {
                    Label("Budgets", systemImage: "chart.pie.fill")
                }

                NavigationLink(destination: GoalsView()) {
                    Label("Goals", systemImage: "target")
                }
            }

            Section("App Settings") {
                NavigationLink(destination: SettingsDebugView()) {
                    Label("Dashboard & Settings", systemImage: "gear")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("More")
    }
}
