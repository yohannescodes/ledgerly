import SwiftUI
import Charts

struct HomeOverviewView: View {
    @EnvironmentObject private var netWorthStore: NetWorthStore
    @EnvironmentObject private var appSettingsStore: AppSettingsStore
    @EnvironmentObject private var transactionsStore: TransactionsStore
    @State private var showingDashboardPreferences = false
    @State private var showingManualEntries = false
    @State private var refreshingStocks = false

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
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: { showingManualEntries = true }) {
                    Image(systemName: "square.and.pencil")
                        .accessibilityLabel("Edit manual entries")
                }
                Button(action: refreshStocks) {
                    if refreshingStocks {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "arrow.triangle.2.circlepath")
                    }
                    Text("")
                        .hidden()
                }
                .accessibilityLabel(refreshingStocks ? "Refreshing prices" : "Refresh stock prices")
                .disabled(refreshingStocks)
                Button(action: { showingDashboardPreferences = true }) {
                    Label("Customize", systemImage: "slider.horizontal.3")
                        .labelStyle(.iconOnly)
                }
            }
        }
        .sheet(isPresented: $showingDashboardPreferences) {
            NavigationStack {
                DashboardPreferencesView()
            }
        }
        .sheet(isPresented: $showingManualEntries) {
            NavigationStack {
                ManualEntriesView()
                    .navigationTitle("Manual Entries")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { showingManualEntries = false }
                        }
                    }
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
                baseCurrencyCode: appSettingsStore.snapshot.baseCurrencyCode,
                snapshots: netWorthStore.snapshots
            )
        case .financialHealth:
            FinancialHealthCard()
        case .expenseBreakdown:
            ExpenseBreakdownCard()
        case .spendingCadence:
            SpendingCadenceCard()
        case .incomeProgress:
            IncomeProgressCard()
        }
    }

    private func refreshStocks() {
        guard !refreshingStocks else { return }
        refreshingStocks = true
        Task {
            await ManualInvestmentPriceService.shared.refresh(baseCurrency: appSettingsStore.snapshot.baseCurrencyCode)
            await MainActor.run {
                refreshingStocks = false
                netWorthStore.reload()
            }
        }
    }
}

#Preview {
    HomeOverviewView()
        .environmentObject(AppSettingsStore(persistence: PersistenceController.preview))
        .environmentObject(NetWorthStore(persistence: PersistenceController.preview))
        .environmentObject(TransactionsStore(persistence: PersistenceController.preview))
        .environmentObject(BudgetsStore(persistence: PersistenceController.preview))
        .environmentObject(WalletsStore(persistence: PersistenceController.preview))
        .environmentObject(GoalsStore(persistence: PersistenceController.preview))
}

// MARK: - Dashboard Cards

struct ExpenseBreakdownCard: View {
    enum Range: String, CaseIterable, Identifiable {
        case week
        case month
        case quarter

        var id: String { rawValue }
        var title: String {
            switch self {
            case .week: return "7D"
            case .month: return "30D"
            case .quarter: return "90D"
            }
        }

        var days: Int {
            switch self {
            case .week: return 7
            case .month: return 30
            case .quarter: return 90
            }
        }

        var startDate: Date {
            let calendar = Calendar.current
            let components: DateComponents
            switch self {
            case .week:
                components = DateComponents(day: -7)
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
                    amountAndBadge
                }
                Spacer()
                Picker("Range", selection: $range) {
                    ForEach(Range.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
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
                .lineLimit(1)
        }
        .font(.caption.bold())
        .fixedSize(horizontal: true, vertical: false)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.15))
        .clipShape(Capsule())
        .foregroundStyle(color)
    }

    private func reload() {
        let breakdown = transactionsStore.fetchExpenseBreakdown(since: range.startDate)
        totals = transactionsStore.fetchExpenseTotals(days: range.days)
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

    private var amountText: some View {
        Text(CurrencyFormatter.string(for: totals.currentTotal, code: appSettingsStore.snapshot.baseCurrencyCode))
            .font(.title3)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .layoutPriority(1)
    }

    @ViewBuilder
    private var amountAndBadge: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                amountText
                changeBadge
            }
            VStack(alignment: .leading, spacing: 6) {
                amountText
                changeBadge
            }
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
    @State private var hasEarlierData = false
    @State private var barAnimationProgress: CGFloat = 0
    @State private var displayedYear: Int = Calendar.current.component(.year, from: Date())

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(headerTitle)
                    .font(.headline)
                Spacer()
                navigationButtons
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
                    Text("Year total")
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
        let result = transactionsStore.fetchIncomeProgress(forYear: displayedYear)
        entries = result.entries
        hasEarlierData = result.hasEarlierData
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

    private var headerTitle: String {
        "Income Progress (\(displayedYear))"
    }

    private var currentYear: Int {
        Calendar.current.component(.year, from: Date())
    }

    private var canGoForward: Bool { displayedYear < currentYear }

    private var navigationButtons: some View {
        HStack(spacing: 12) {
            Button {
                displayedYear -= 1
                reload()
            } label: {
                Label("Previous", systemImage: "chevron.left")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.plain)
            .disabled(!hasEarlierData)

            Button {
                displayedYear = min(displayedYear + 1, currentYear)
                reload()
            } label: {
                Label("Next", systemImage: "chevron.right")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.plain)
            .disabled(!canGoForward)
        }
    }

    private func formatMonth(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: date)
    }
}
