import SwiftUI
import Charts

struct NetWorthHistoryCard: View {
    let totals: NetWorthTotals?
    let baseCurrencyCode: String
    @State private var chartAnimationProgress: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text("Net Worth Breakdown")
                    .font(.headline)
                Spacer()
                if let totals {
                    Text(CurrencyFormatter.string(for: totals.netWorth, code: baseCurrencyCode))
                        .font(.title3.bold())
                        .foregroundStyle(.primary)
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

    private func segments(for totals: NetWorthTotals) -> [NetWorthSegment] {
        let liabilityAmount: Decimal
        if totals.totalLiabilities < 0 {
            liabilityAmount = -totals.totalLiabilities
        } else {
            liabilityAmount = totals.totalLiabilities
        }
        return [
            NetWorthSegment(label: "Assets", amount: totals.manualAssets, color: .blue.opacity(0.8)),
            NetWorthSegment(label: "Investments", amount: totals.totalInvestments, color: .purple.opacity(0.8)),
            NetWorthSegment(label: "Wallets", amount: totals.walletAssets, color: .green.opacity(0.8)),
            NetWorthSegment(label: "Receivables", amount: totals.receivables, color: .orange.opacity(0.8)),
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
