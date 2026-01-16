import SwiftUI
import Charts

struct NetWorthHistoryCard: View {
    let totals: NetWorthTotals?
    let baseCurrencyCode: String
    let snapshots: [NetWorthSnapshotModel]
    @State private var chartAnimationProgress: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text("Net Worth Breakdown")
                    .font(.headline)
                Spacer()
                if let totals {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(CurrencyFormatter.string(for: totals.netWorth, code: baseCurrencyCode))
                            .font(.title3.bold())
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        if let change = netWorthChange {
                            VStack(alignment: .trailing, spacing: 2) {
                                changeRow(change)
                                Text("vs last snapshot")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            if let totals {
                let data = segments(for: totals)
                if data.isEmpty {
                    Text("Add wallets, investments, or liabilities to see how they shape your net worth.")
                        .foregroundStyle(.secondary)
                } else {
                    Chart(data) { segment in
                        SectorMark(
                            angle: .value("Amount", segment.doubleValue * Double(chartAnimationProgress)),
                            innerRadius: .ratio(0.45),
                            outerRadius: .ratio(1)
                        )
                        .foregroundStyle(segment.color)
                    }
                    .frame(height: 220)
                    .chartLegend(.hidden)
                    .animation(.spring(response: 0.8, dampingFraction: 0.8), value: chartAnimationProgress)

                    ForEach(data) { segment in
                        HStack {
                            Circle()
                                .fill(segment.color)
                                .frame(width: 10, height: 10)
                            Text(segment.label)
                            Spacer()
                            Text(CurrencyFormatter.string(for: segment.amount, code: baseCurrencyCode))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } else {
                Text("Add wallets, investments, or liabilities to see how they shape your net worth.")
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .onAppear(perform: triggerAnimation)
        .onChange(of: totals?.netWorth ?? .zero) { _ in
            triggerAnimation()
        }
    }

    private var netWorthChange: NetWorthChange? {
        guard let totals, let previousSnapshot = snapshots.last else { return nil }
        let current = totals.netWorth
        let previous = previousSnapshot.netWorth
        let delta = current - previous
        let percent: Decimal?
        if previous == .zero {
            percent = nil
        } else {
            let denominator = previous < 0 ? -previous : previous
            percent = delta / denominator
        }
        return NetWorthChange(delta: delta, percent: percent)
    }

    private func signedCurrency(_ value: Decimal, code: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        formatter.positivePrefix = "+"
        return formatter.string(from: value as NSNumber) ?? "--"
    }

    private func changeRow(_ change: NetWorthChange) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) {
                deltaText(change)
                changeBadge(change)
            }
            VStack(alignment: .trailing, spacing: 4) {
                deltaText(change)
                changeBadge(change)
            }
        }
    }

    private func deltaText(_ change: NetWorthChange) -> some View {
        Text(signedCurrency(change.delta, code: baseCurrencyCode))
            .font(.caption.bold())
            .foregroundStyle(change.delta >= 0 ? .green : .red)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }

    private func changeBadge(_ change: NetWorthChange) -> some View {
        let arrow = change.delta >= 0 ? "arrow.up" : "arrow.down"
        let color: Color = change.delta >= 0 ? .green : .red
        let pctText: String
        if let percent = change.percent {
            let formatter = NumberFormatter()
            formatter.numberStyle = .percent
            formatter.maximumFractionDigits = 1
            pctText = formatter.string(from: percent as NSNumber) ?? "--"
        } else {
            pctText = change.delta == .zero ? "0%" : "--"
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

    private func segments(for totals: NetWorthTotals) -> [NetWorthSegment] {
        let liabilityAmount: Decimal
        if totals.totalLiabilities < 0 {
            liabilityAmount = -totals.totalLiabilities
        } else {
            liabilityAmount = totals.totalLiabilities
        }
        return [
            NetWorthSegment(label: "Wallets", amount: totals.walletAssets, color: .green.opacity(0.8)),
            NetWorthSegment(label: "Tangible Assets", amount: totals.tangibleAssets, color: .blue.opacity(0.8)),
            NetWorthSegment(label: "Receivables", amount: totals.receivables, color: .orange.opacity(0.8)),
            NetWorthSegment(label: "Investments", amount: totals.totalInvestments, color: .purple.opacity(0.8)),
            NetWorthSegment(label: "Liabilities", amount: liabilityAmount, color: .red.opacity(0.8))
        ]
        .filter { $0.amount > 0 }
    }
}

private struct NetWorthSegment: Identifiable {
    let id = UUID()
    let label: String
    let amount: Decimal
    let color: Color

    var doubleValue: Double { NSDecimalNumber(decimal: amount).doubleValue }
}

private struct NetWorthChange {
    let delta: Decimal
    let percent: Decimal?
}

private extension NetWorthHistoryCard {
    func triggerAnimation() {
        guard let totals, !segments(for: totals).isEmpty else {
            chartAnimationProgress = 0
            return
        }
        chartAnimationProgress = 0
        withAnimation(.spring(response: 0.9, dampingFraction: 0.85)) {
            chartAnimationProgress = 1
        }
    }
}
