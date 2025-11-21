import SwiftUI

struct HomeOverviewView: View {
    @EnvironmentObject private var netWorthStore: NetWorthStore
    @FetchRequest(sortDescriptors: [SortDescriptor(\.timestamp, order: .reverse)])
    private var snapshots: FetchedResults<NetWorthSnapshot>

    var body: some View {
        VStack(spacing: 24) {
            NetWorthSummaryCard(snapshot: netWorthStore.latestSnapshot)
            NetWorthHistoryList(snapshots: snapshots)
            Text("More dashboard widgets coming in later phases.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            NavigationLink("Manage Manual Assets & Liabilities") {
                ManualEntriesView()
            }
        }
        .padding()
        .onAppear { netWorthStore.reload() }
    }
}

private struct NetWorthSummaryCard: View {
    let snapshot: NetWorthSnapshotModel?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Net Worth")
                .font(.headline)
            if let snapshot {
                VStack(alignment: .leading, spacing: 8) {
                    metricRow(title: "Total Assets", value: snapshot.totalAssets)
                    metricRow(title: "Total Liabilities", value: snapshot.totalLiabilities)
                    metricRow(title: "Core Net Worth", value: snapshot.coreNetWorth)
                    metricRow(title: "Tangible Net Worth", value: snapshot.tangibleNetWorth)
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

private struct NetWorthHistoryList: View {
    let snapshots: FetchedResults<NetWorthSnapshot>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("History")
                .font(.headline)
            if snapshots.isEmpty {
                Text("No snapshots yet")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(snapshots.prefix(5)) { snapshot in
                    HStack {
                        Text(snapshot.timestamp ?? Date(), style: .date)
                        Spacer()
                        Text(formatCurrency(snapshot.coreNetWorth as Decimal? ?? .zero))
                            .fontWeight(.semibold)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
        .environmentObject(NetWorthStore(persistence: PersistenceController.preview))
}
