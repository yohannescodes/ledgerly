import SwiftUI
import Charts

struct NetWorthAnalyticsView: View {
    @EnvironmentObject private var netWorthStore: NetWorthStore
    @State private var selectedRange: NetWorthRange
    @State private var enabledMetrics: Set<NetWorthMetric> = NetWorthMetric.defaultVisible
    @State private var editingSnapshot: NetWorthSnapshotModel?

    init(initialRange: NetWorthRange = .sixMonths) {
        _selectedRange = State(initialValue: initialRange)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                chartCard
                overlaysCard
                annotationsCard
            }
            .padding()
        }
        .navigationTitle("Net Worth Analytics")
        .sheet(item: $editingSnapshot) { snapshot in
            NetWorthAnnotationEditor(snapshot: snapshot) { notes in
                netWorthStore.updateSnapshotNotes(snapshotID: snapshot.id, notes: notes)
            }
        }
        .onAppear { netWorthStore.reload() }
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("History")
                        .font(.headline)
                    if let summary = changeSummary {
                        Text(summary)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Picker("Range", selection: $selectedRange) {
                    ForEach(NetWorthRange.allCases) { range in
                        Text(range.title).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 280)
            }

            if filteredSnapshots.count >= 2 {
                chartView
                    .frame(height: 240)
            } else if filteredSnapshots.count == 1 {
                singlePointChart
                    .frame(height: 120)
            } else {
                Text(netWorthStore.snapshots.isEmpty ?
                     "No snapshots yet. Capture more history to unlock analytics." :
                        "No snapshots in this range. Try expanding the filter.")
                .foregroundStyle(.secondary)
            }

            if let latest = latestSnapshot {
                Divider().padding(.top, 4)
                latestSnapshotBreakdown(for: latest)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 18).fill(Color(.secondarySystemBackground)))
    }

    private var overlaysCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Overlays")
                .font(.headline)
            Text("Toggle which lines appear on the chart.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            ForEach(NetWorthMetric.allCases) { metric in
                Toggle(isOn: binding(for: metric)) {
                    Label(metric.title, systemImage: metric.iconName)
                        .labelStyle(.titleAndIcon)
                }
                .toggleStyle(.switch)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 18).fill(Color(.secondarySystemBackground)))
    }

    private var annotationsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Snapshot Notes")
                .font(.headline)
            if annotationList.isEmpty {
                Text("Switch to a longer range to see available snapshots.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(annotationList) { snapshot in
                    annotationRow(for: snapshot)
                    if snapshot.id != annotationList.last?.id {
                        Divider()
                    }
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 18).fill(Color(.secondarySystemBackground)))
    }

    private var chartView: some View {
        Chart {
            ForEach(sortedMetrics, id: \.self) { metric in
                ForEach(filteredSnapshots) { snapshot in
                    LineMark(
                        x: .value("Date", snapshot.timestamp),
                        y: .value(metric.title, doubleValue(metric.value(for: snapshot)))
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(metric.color)
                }
            }

            ForEach(annotationSnapshots) { snapshot in
                PointMark(
                    x: .value("Date", snapshot.timestamp),
                    y: .value("Annotated", doubleValue(snapshot.coreNetWorth))
                )
                .foregroundStyle(.orange)
                .annotation(position: .top) {
                    Label("", systemImage: "note.text")
                        .labelStyle(.iconOnly)
                        .foregroundStyle(.orange)
                }
            }
        }
        .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) }
        .chartYAxis { AxisMarks(position: .leading) }
    }

    private var singlePointChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let snapshot = filteredSnapshots.first {
                Text(snapshot.timestamp, style: .date)
                Text(formatCurrency(snapshot.coreNetWorth))
                    .font(.title3.weight(.semibold))
            }
        }
    }

    private func annotationRow(for snapshot: NetWorthSnapshotModel) -> some View {
        Button(action: { editingSnapshot = snapshot }) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(snapshot.timestamp, style: .date)
                        .font(.subheadline)
                    Text(formatCurrency(snapshot.coreNetWorth))
                        .font(.body.weight(.semibold))
                    Text(snapshot.notes?.isEmpty == false ? snapshot.notes! : "Add a note")
                        .font(.footnote)
                        .lineLimit(2)
                        .foregroundStyle(snapshot.notes?.isEmpty == false ? Color.primary : .secondary)
                }
                Spacer()
                Image(systemName: "square.and.pencil")
                    .foregroundStyle(Color.accentColor)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    private var filteredSnapshots: [NetWorthSnapshotModel] {
        selectedRange.filter(snapshots: netWorthStore.snapshots)
    }

    private var annotationSnapshots: [NetWorthSnapshotModel] {
        filteredSnapshots.filter { ($0.notes ?? "").isEmpty == false }
    }

    private var annotationList: [NetWorthSnapshotModel] {
        Array(filteredSnapshots.suffix(12))
    }

    private var sortedMetrics: [NetWorthMetric] {
        let metrics = enabledMetrics.isEmpty ? NetWorthMetric.defaultVisible : enabledMetrics
        return metrics.sorted { $0.rawValue < $1.rawValue }
    }

    private var latestSnapshot: NetWorthSnapshotModel? {
        filteredSnapshots.last ?? netWorthStore.snapshots.last
    }

    private var changeSummary: String? {
        guard let first = filteredSnapshots.first, let last = filteredSnapshots.last, first.id != last.id else { return nil }
        let delta = last.coreNetWorth - first.coreNetWorth
        let percent = first.coreNetWorth == .zero ? nil : (delta / first.coreNetWorth) * 100
        var parts = ["Δ \(formatCurrency(delta))"]
        if let percent {
            let formatter = NumberFormatter()
            formatter.maximumFractionDigits = 2
            if let formatted = formatter.string(from: percent as NSNumber) {
                parts.append("(\(formatted)% )")
            }
        }
        return parts.joined(separator: " ")
    }

    private func binding(for metric: NetWorthMetric) -> Binding<Bool> {
        Binding(
            get: { enabledMetrics.contains(metric) },
            set: { isOn in
                if isOn {
                    enabledMetrics.insert(metric)
                } else if enabledMetrics.count > 1 {
                    enabledMetrics.remove(metric)
                }
            }
        )
    }

    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = Locale.current.currency?.identifier ?? "USD"
        return formatter.string(from: value as NSNumber) ?? "--"
    }
    private func latestSnapshotBreakdown(for snapshot: NetWorthSnapshotModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Latest Snapshot")
                .font(.headline)
            MetricRow(title: "Total Assets", value: snapshot.totalAssets)
            MetricRow(title: "Total Liabilities", value: snapshot.totalLiabilities)
            MetricRow(title: "Core Net Worth", value: snapshot.coreNetWorth)
            MetricRow(title: "Tangible Net Worth", value: snapshot.tangibleNetWorth)
            MetricRow(title: "Volatile Assets", value: snapshot.volatileAssets)
        }
    }

    private func doubleValue(_ value: Decimal) -> Double {
        NSDecimalNumber(decimal: value).doubleValue
    }
}

private struct MetricRow: View {
    let title: String
    let value: Decimal

    var body: some View {
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

private struct NetWorthAnnotationEditor: View {
    let snapshot: NetWorthSnapshotModel
    let onSave: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var notes: String

    init(snapshot: NetWorthSnapshotModel, onSave: @escaping (String) -> Void) {
        self.snapshot = snapshot
        self.onSave = onSave
        _notes = State(initialValue: snapshot.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text(snapshot.timestamp, style: .date)) {
                    TextEditor(text: $notes)
                        .frame(minHeight: 120)
                }
            }
            .navigationTitle("Edit Note")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: dismiss.callAsFunction)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                }
            }
        }
    }

    private func save() {
        onSave(notes)
        dismiss()
    }
}

private extension NetWorthMetric {
    var iconName: String {
        switch self {
        case .total: return "sum"
        case .core: return "circle.grid.cross.left.fill"
        case .tangible: return "cube.box"
        case .volatile: return "bolt.fill"
        }
    }
}
