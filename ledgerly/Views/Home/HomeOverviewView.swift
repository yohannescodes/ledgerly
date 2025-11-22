import SwiftUI
import Charts

struct HomeOverviewView: View {
    @EnvironmentObject private var netWorthStore: NetWorthStore
    @EnvironmentObject private var appSettingsStore: AppSettingsStore
    @EnvironmentObject private var transactionsStore: TransactionsStore
    @State private var showingDashboardPreferences = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if orderedWidgets.isEmpty {
                    Text("Customize your dashboard from Settings → Dashboard.")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()
                } else {
                    ForEach(orderedWidgets) { widget in
                        widgetView(for: widget)
                    }
                }
                NavigationLink("Manage Manual Assets, Investments & Liabilities") {
                    ManualEntriesView()
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
        }
        .navigationTitle(dashboardTitle)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingDashboardPreferences = true }) {
                    Label("Customize", systemImage: "slider.horizontal.3")
                }
            }
        }
        .sheet(isPresented: $showingDashboardPreferences) {
            NavigationStack {
                DashboardPreferencesView()
            }
        }
        .task(id: appSettingsStore.snapshot.baseCurrencyCode) {
            await ManualInvestmentPriceService.shared.refresh(baseCurrency: appSettingsStore.snapshot.baseCurrencyCode)
            await MainActor.run { netWorthStore.reload() }
        }
        .onAppear { netWorthStore.reload() }
    }

    private var orderedWidgets: [DashboardWidget] {
        appSettingsStore.snapshot.dashboardWidgets
    }

    private var dashboardTitle: String {
        if let name = Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String, !name.isEmpty {
            return "\(name) Dashboard"
        }
        return "Your Dashboard"
    }

    @ViewBuilder
    private func widgetView(for widget: DashboardWidget) -> some View {
        switch widget {
        case .budgetSummary:
            BudgetSummaryCard()
        case .goalsSummary:
            GoalsSummaryCard()
        case .netWorthHistory:
            NetWorthHistoryCard(
                totals: netWorthStore.liveTotals,
                baseCurrencyCode: appSettingsStore.snapshot.baseCurrencyCode
            )
        case .expenseBreakdown:
            ExpenseBreakdownCard()
        case .incomeProgress:
            IncomeProgressCard()
        }
    }
}

#Preview {
    HomeOverviewView()
        .environmentObject(AppSettingsStore(persistence: PersistenceController.preview))
        .environmentObject(NetWorthStore(persistence: PersistenceController.preview))
        .environmentObject(TransactionsStore(persistence: PersistenceController.preview))
        .environmentObject(BudgetsStore(persistence: PersistenceController.preview))
        .environmentObject(GoalsStore(persistence: PersistenceController.preview))
}

// MARK: - Dashboard Cards

struct ExpenseBreakdownCard: View {
    enum Range: String, CaseIterable, Identifiable {
        case month
        case quarter

        var id: String { rawValue }
        var title: String {
            switch self {
            case .month: return "30D"
            case .quarter: return "90D"
            }
        }

        var startDate: Date {
            let calendar = Calendar.current
            let components: DateComponents
            switch self {
            case .month:
                components = DateComponents(day: -30)
            case .quarter:
                components = DateComponents(day: -90)
            }
            return calendar.date(byAdding: components, to: Date()) ?? Date()
        }
    }

    @EnvironmentObject private var transactionsStore: TransactionsStore
    @EnvironmentObject private var appSettingsStore: AppSettingsStore
    @State private var range: Range = .month
    @State private var segments: [ExpenseSegment] = []
    @State private var totals = TransactionsStore.ExpenseTotals(currentTotal: .zero, previousTotal: .zero)
    @State private var pieAnimationProgress: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Expense Breakdown")
                        .font(.headline)
                    HStack(spacing: 8) {
                        Text(CurrencyFormatter.string(for: totals.currentTotal, code: appSettingsStore.snapshot.baseCurrencyCode))
                            .font(.title3.bold())
                        changeBadge
                    }
                }
                Spacer()
                Picker("Range", selection: $range) {
                    ForEach(Range.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 140)
            }

            if segments.isEmpty {
                Text("Log expenses to see where your money goes.")
                    .foregroundStyle(.secondary)
            } else {
                Chart(segments) { segment in
                    SectorMark(
                        angle: .value("Amount", segment.amountValue * Double(pieAnimationProgress)),
                        innerRadius: .ratio(0.45),
                        outerRadius: .ratio(1)
                    )
                    .foregroundStyle(segment.color)
                }
                .frame(height: 220)
                .chartLegend(.hidden)
                .animation(.spring(response: 0.8, dampingFraction: 0.85), value: pieAnimationProgress)

                ForEach(segments) { segment in
                    HStack {
                        Circle()
                            .fill(segment.color)
                            .frame(width: 10, height: 10)
                        Text(segment.label)
                        Spacer()
                        Text(CurrencyFormatter.string(for: segment.amount, code: appSettingsStore.snapshot.baseCurrencyCode))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .onAppear(perform: reload)
        .onChange(of: range) { _ in reload() }
    }

    private var changeBadge: some View {
        let delta = totals.currentTotal - totals.previousTotal
        let percentage = totals.previousTotal == .zero ? nil : (delta / totals.previousTotal)
        let arrow: String
        let color: Color
        if let percentage {
            if percentage >= 0 {
                arrow = "arrow.up"
                color = .red
            } else {
                arrow = "arrow.down"
                color = .green
            }
        } else {
            arrow = "circle"
            color = .secondary
        }
        let pctText: String
        if let percentage {
            let formatter = NumberFormatter()
            formatter.numberStyle = .percent
            formatter.maximumFractionDigits = 1
            pctText = formatter.string(from: (percentage as NSDecimalNumber)) ?? "--"
        } else if totals.currentTotal == .zero {
            pctText = "0%"
        } else {
            pctText = "--"
        }
        return HStack(spacing: 4) {
            Image(systemName: arrow)
            Text(pctText)
        }
        .font(.caption.bold())
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.15))
        .clipShape(Capsule())
        .foregroundStyle(color)
    }

    private func reload() {
        let breakdown = transactionsStore.fetchExpenseBreakdown(since: range.startDate)
        totals = transactionsStore.fetchMonthlyExpenseTotals()
        let palette: [Color] = [.pink, .orange, .purple, .blue, .green, .yellow, .teal, .indigo]
        let mapped: [ExpenseSegment] = breakdown.enumerated().map { index, entry in
            let color = Color(hex: entry.colorHex ?? "") ?? palette[index % palette.count].opacity(0.85)
            return ExpenseSegment(label: entry.label, amount: entry.convertedAmount, color: color)
        }
        segments = mapped
        restartPieAnimation()
    }

    private func restartPieAnimation() {
        guard !segments.isEmpty else {
            pieAnimationProgress = 0
            return
        }
        pieAnimationProgress = 0
        withAnimation(.spring(response: 0.9, dampingFraction: 0.85)) {
            pieAnimationProgress = 1
        }
    }
}

private struct ExpenseSegment: Identifiable {
    let id = UUID()
    let label: String
    let amount: Decimal
    let color: Color

    var amountValue: Double { NSDecimalNumber(decimal: amount).doubleValue }
}

struct IncomeProgressCard: View {
    @EnvironmentObject private var transactionsStore: TransactionsStore
    @EnvironmentObject private var appSettingsStore: AppSettingsStore
    @State private var entries: [TransactionsStore.IncomeProgressEntry] = []
    @State private var barAnimationProgress: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Income Progress (12M)")
                    .font(.headline)
                Spacer()
                if let latest = entries.last {
                    Text(CurrencyFormatter.string(for: latest.amount, code: appSettingsStore.snapshot.baseCurrencyCode))
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)
                }
            }

            if entries.isEmpty {
                Text("Log income transactions to visualize progress.")
                    .foregroundStyle(.secondary)
            } else {
                Chart(entries) { entry in
                    BarMark(
                        x: .value("Month", entry.monthStart, unit: .month),
                        y: .value("Income", NSDecimalNumber(decimal: entry.amount).doubleValue * Double(barAnimationProgress))
                    )
                    .foregroundStyle(Color.green.gradient)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month)) { value in
                        if let date = value.as(Date.self) {
                            AxisValueLabel(formatMonth(date))
                        }
                    }
                }
                .frame(height: 220)
                .animation(.spring(response: 0.9, dampingFraction: 0.75), value: barAnimationProgress)

                HStack {
                    Text("Year-to-date")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(CurrencyFormatter.string(for: totalAmount, code: appSettingsStore.snapshot.baseCurrencyCode))
                        .font(.caption.bold())
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .onAppear(perform: reload)
    }

    private var totalAmount: Decimal {
        entries.reduce(.zero) { $0 + $1.amount }
    }

    private func reload() {
        entries = transactionsStore.fetchMonthlyIncomeProgress()
        restartBarAnimation()
    }

    private func restartBarAnimation() {
        guard !entries.isEmpty else {
            barAnimationProgress = 0
            return
        }
        barAnimationProgress = 0
        withAnimation(.spring(response: 0.9, dampingFraction: 0.8)) {
            barAnimationProgress = 1
        }
    }

    private func formatMonth(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: date)
    }
}
