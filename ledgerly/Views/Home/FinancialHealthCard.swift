import SwiftUI

struct FinancialHealthCard: View {
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

        func startDate(reference: Date) -> Date {
            Calendar.current.date(byAdding: .day, value: -days, to: reference) ?? reference
        }
    }

    @EnvironmentObject private var transactionsStore: TransactionsStore
    @EnvironmentObject private var netWorthStore: NetWorthStore
    @EnvironmentObject private var appSettingsStore: AppSettingsStore
    @State private var range: Range = .month
    @State private var cashFlowSnapshot: TransactionsStore.CashFlowSnapshot?
    @State private var topExpense: TransactionsStore.TopExpenseCategory?
    @State private var investmentPerformance: ManualInvestmentPerformanceSnapshot?
    @State private var fxExposure: FxExposureSnapshot?

    var body: some View {
        let baseCurrency = appSettingsStore.snapshot.baseCurrencyCode
        let snapshot = cashFlowSnapshot ?? placeholderSnapshot
        let cashFlowValue = CurrencyFormatter.string(for: snapshot.netCashFlow, code: baseCurrency)
        let cashFlowSubtitle = "Income \(CurrencyFormatter.string(for: snapshot.incomeTotal, code: baseCurrency)) | Spend \(CurrencyFormatter.string(for: snapshot.expenseTotal, code: baseCurrency))"
        let liquidity = liquiditySnapshot
        let liquidityShare = liquidity.flatMap { $0.share }
        let liquidityValue = percentString(liquidityShare)
        let liquiditySubtitle = liquidity.map { liquiditySubtitleText($0, baseCurrency: baseCurrency) }
        let investmentValue = investmentPerformance.map { signedCurrency($0.totalProfit, code: baseCurrency) } ?? "--"
        let investmentSubtitle = investmentPerformance.map {
            "Value \(CurrencyFormatter.string(for: $0.totalCurrentValue, code: baseCurrency))"
        } ?? "Add investments to track performance"
        let fxShareValue = percentString(fxExposure.flatMap { $0.foreignAssetShare })
        let fxSubtitle = fxExposure.map { "Foreign \(CurrencyFormatter.string(for: $0.foreignAssets, code: baseCurrency))" }

        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Financial Health")
                    .font(.headline)
                Spacer()
                Picker("Range", selection: $range) {
                    ForEach(Range.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                MetricTile(
                    title: "Cash Flow",
                    value: cashFlowValue,
                    subtitle: cashFlowSubtitle,
                    badge: trendBadge(current: snapshot.netCashFlow, previous: snapshot.previousNetCashFlow, positiveIsGood: true)
                )
                MetricTile(
                    title: "Liquidity",
                    value: liquidityValue,
                    subtitle: liquiditySubtitle ?? "Add wallets to measure liquidity",
                    badge: AnyView(EmptyView())
                )
                MetricTile(
                    title: "Investments",
                    value: investmentValue,
                    subtitle: investmentSubtitle,
                    badge: AnyView(EmptyView())
                )
                MetricTile(
                    title: "FX Exposure",
                    value: fxShareValue,
                    subtitle: fxSubtitle ?? "No FX assets yet",
                    badge: AnyView(EmptyView())
                )
            }

            Text(commentaryText(baseCurrency: baseCurrency, snapshot: snapshot))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .onAppear(perform: reload)
        .onChange(of: range) { _ in reload() }
        .onChange(of: appSettingsStore.snapshot) { _ in reload() }
        .onChange(of: netWorthStore.liveTotals?.netWorth ?? .zero) { _ in
            investmentPerformance = netWorthStore.fetchManualInvestmentPerformance()
            fxExposure = netWorthStore.fetchFxExposure()
        }
    }

    private var placeholderSnapshot: TransactionsStore.CashFlowSnapshot {
        let now = Date()
        return TransactionsStore.CashFlowSnapshot(
            start: now,
            end: now,
            incomeTotal: .zero,
            expenseTotal: .zero,
            previousIncomeTotal: .zero,
            previousExpenseTotal: .zero
        )
    }

    private var liquiditySnapshot: LiquiditySnapshot? {
        guard let totals = netWorthStore.liveTotals else { return nil }
        let liquid = totals.walletAssets
        let totalAssets = totals.totalAssets
        let illiquid = max(totalAssets - liquid, .zero)
        let share = totalAssets == .zero ? nil : (liquid / totalAssets)
        let ratio = illiquid == .zero ? nil : (liquid / illiquid)
        return LiquiditySnapshot(liquid: liquid, illiquid: illiquid, share: share, ratio: ratio)
    }

    private func reload() {
        let now = Date()
        cashFlowSnapshot = transactionsStore.fetchCashFlowSnapshot(days: range.days, referenceDate: now)
        topExpense = transactionsStore.fetchTopExpenseCategory(start: range.startDate(reference: now), end: now)
        investmentPerformance = netWorthStore.fetchManualInvestmentPerformance()
        fxExposure = netWorthStore.fetchFxExposure()
    }

    private func signedCurrency(_ value: Decimal, code: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        formatter.positivePrefix = "+"
        return formatter.string(from: value as NSNumber) ?? "--"
    }

    private func percentString(_ value: Decimal?) -> String {
        guard let value else { return "--" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 1
        return formatter.string(from: value as NSNumber) ?? "--"
    }

    private func ratioString(_ value: Decimal?) -> String {
        guard let value else { return "--" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        let text = formatter.string(from: value as NSNumber) ?? "--"
        return "\(text)x"
    }

    private func liquiditySubtitleText(_ snapshot: LiquiditySnapshot, baseCurrency: String) -> String {
        if snapshot.illiquid == .zero {
            return "All liquid assets"
        }
        let liquidAmount = CurrencyFormatter.string(for: snapshot.liquid, code: baseCurrency)
        return "Liquid \(liquidAmount) | \(ratioString(snapshot.ratio)) ratio"
    }

    private func trendBadge(current: Decimal, previous: Decimal, positiveIsGood: Bool) -> AnyView {
        let delta = current - previous
        let percentage: Decimal?
        if previous == .zero {
            percentage = nil
        } else {
            let denominator = previous < 0 ? -previous : previous
            percentage = delta / denominator
        }
        let arrow: String
        let color: Color
        if percentage != nil {
            if delta >= 0 {
                arrow = "arrow.up"
                color = positiveIsGood ? .green : .red
            } else {
                arrow = "arrow.down"
                color = positiveIsGood ? .red : .green
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
            pctText = formatter.string(from: percentage as NSNumber) ?? "--"
        } else if current == .zero {
            pctText = "0%"
        } else {
            pctText = "--"
        }
        return AnyView(
            HStack(spacing: 4) {
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
        )
    }

    private func commentaryText(baseCurrency: String, snapshot: TransactionsStore.CashFlowSnapshot) -> String {
        if let topExpense {
            let amount = CurrencyFormatter.string(for: topExpense.amount, code: baseCurrency)
            let pct = percentString(topExpense.share)
            return "Top spend: \(topExpense.label) at \(amount) (\(pct) of expenses)."
        }
        if snapshot.expenseTotal == .zero {
            return "No expenses logged for this period."
        }
        return "Log expenses to see your biggest spending drivers."
    }
}

private struct LiquiditySnapshot {
    let liquid: Decimal
    let illiquid: Decimal
    let share: Decimal?
    let ratio: Decimal?
}

private struct MetricTile: View {
    let title: String
    let value: String
    let subtitle: String
    let badge: AnyView

    init(title: String, value: String, subtitle: String, badge: AnyView) {
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.badge = badge
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                badge
                    .layoutPriority(1)
            }
            Text(value)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(12)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    FinancialHealthCard()
        .environmentObject(AppSettingsStore(persistence: PersistenceController.preview))
        .environmentObject(NetWorthStore(persistence: PersistenceController.preview))
        .environmentObject(TransactionsStore(persistence: PersistenceController.preview))
}
