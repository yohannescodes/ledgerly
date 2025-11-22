import Foundation

enum DashboardWidget: String, CaseIterable, Identifiable, Codable {
    case netWorthSummary
    case netWorthHistory
    case budgetSummary
    case goalsSummary

    var id: String { rawValue }

    var title: String {
        switch self {
        case .netWorthSummary: return "Net Worth Snapshot"
        case .netWorthHistory: return "Net Worth Trend"
        case .budgetSummary: return "Budgets"
        case .goalsSummary: return "Goals"
        }
    }

    var detail: String {
        switch self {
        case .netWorthSummary:
            return "Latest totals broken down by assets and liabilities."
        case .netWorthHistory:
            return "Historical chart with annotations and overlays."
        case .budgetSummary:
            return "Top monthly budgets with utilization."
        case .goalsSummary:
            return "Upcoming goals with progress and deadlines."
        }
    }

    var iconName: String {
        switch self {
        case .netWorthSummary: return "chart.pie"
        case .netWorthHistory: return "chart.line.uptrend.xyaxis"
        case .budgetSummary: return "chart.bar"
        case .goalsSummary: return "target"
        }
    }

    static var defaultOrder: [DashboardWidget] {
        [.netWorthSummary, .netWorthHistory, .budgetSummary, .goalsSummary]
    }
}

enum DashboardWidgetStorage {
    static func encode(_ widgets: [DashboardWidget]) -> String {
        widgets.map(\.rawValue).joined(separator: ",")
    }

    static func decode(_ stored: String?) -> [DashboardWidget] {
        guard let stored, !stored.isEmpty else { return DashboardWidget.defaultOrder }
        let widgets = stored
            .split(separator: ",")
            .compactMap { DashboardWidget(rawValue: String($0)) }
        return widgets.isEmpty ? DashboardWidget.defaultOrder : widgets
    }
}
