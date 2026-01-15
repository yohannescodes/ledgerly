import Foundation

enum DashboardWidget: String, CaseIterable, Identifiable, Codable {
    case netWorthHistory
    case expenseBreakdown
    case spendingCadence
    case incomeProgress
    case budgetSummary
    case goalsSummary

    var id: String { rawValue }

    var title: String {
        switch self {
        case .netWorthHistory: return "Net Worth Breakdown"
        case .expenseBreakdown: return "Expense Breakdown"
        case .spendingCadence: return "Spending Cadence"
        case .incomeProgress: return "Income Progress"
        case .budgetSummary: return "Budgets"
        case .goalsSummary: return "Goals"
        }
    }

    var detail: String {
        switch self {
        case .netWorthHistory:
            return "See how each asset class contributes to your total net worth."
        case .expenseBreakdown:
            return "Visualize where your spending goes across categories."
        case .spendingCadence:
            return "Track daily, weekly, and monthly spending totals."
        case .incomeProgress:
            return "Track monthly income for the past year."
        case .budgetSummary:
            return "Top monthly budgets with utilization."
        case .goalsSummary:
            return "Upcoming goals with progress and deadlines."
        }
    }

    var iconName: String {
        switch self {
        case .netWorthHistory: return "chart.line.uptrend.xyaxis"
        case .expenseBreakdown: return "chart.pie"
        case .spendingCadence: return "calendar"
        case .incomeProgress: return "chart.bar.xaxis"
        case .budgetSummary: return "chart.bar"
        case .goalsSummary: return "target"
        }
    }

    static var defaultOrder: [DashboardWidget] {
        [.netWorthHistory, .expenseBreakdown, .spendingCadence, .incomeProgress, .budgetSummary, .goalsSummary]
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
