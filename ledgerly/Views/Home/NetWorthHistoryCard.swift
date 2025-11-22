import SwiftUI
import Charts

struct NetWorthHistoryCard: View {
    let snapshots: [NetWorthSnapshotModel]
    @State private var selectedRange: NetWorthRange = .threeMonths

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Net Worth Trend")
                        .font(.headline)
                    if let latest = snapshots.last {
                        Text(formatCurrency(latest.netWorth))
                            .font(.title2.bold())
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .layoutPriority(1)
                    }
                }
                Spacer()
                Picker("Range", selection: $selectedRange) {
                    ForEach(NetWorthRange.allCases) { range in
                        Text(range.title).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }
            Chart(filteredSnapshots) { snapshot in
                LineMark(
                    x: .value("Date", snapshot.timestamp),
                    y: .value("Net Worth", doubleValue(snapshot.netWorth))
                )
                AreaMark(
                    x: .value("Date", snapshot.timestamp),
                    y: .value("Net Worth", doubleValue(snapshot.netWorth))
                )
                .foregroundStyle(Gradient(colors: [.accentColor.opacity(0.4), .clear]))

                if let notes = snapshot.notes, !notes.isEmpty {
                    PointMark(
                        x: .value("Date", snapshot.timestamp),
                        y: .value("Annotation", doubleValue(snapshot.netWorth))
                    )
                    .foregroundStyle(.orange)
                }
            }
            .frame(height: 160)
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)

            NavigationLink {
                NetWorthAnalyticsView(initialRange: selectedRange)
            } label: {
                HStack(spacing: 6) {
                    Text("Open Analytics")
                    Image(systemName: "arrow.right")
                        .imageScale(.small)
                }
                .font(.subheadline.weight(.semibold))
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    private var filteredSnapshots: [NetWorthSnapshotModel] {
        selectedRange.filter(snapshots: snapshots)
    }

    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = Locale.current.currency?.identifier ?? "USD"
        return formatter.string(from: value as NSNumber) ?? "--"
    }

    private func doubleValue(_ value: Decimal) -> Double {
        NSDecimalNumber(decimal: value).doubleValue
    }
}
