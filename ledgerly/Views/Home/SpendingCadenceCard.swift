import CoreData
import SwiftUI

struct SpendingCadenceCard: View {
    @EnvironmentObject private var transactionsStore: TransactionsStore
    @EnvironmentObject private var appSettingsStore: AppSettingsStore
    @Environment(\.managedObjectContext) private var context
    @State private var snapshot: TransactionsStore.SpendingCadenceSnapshot?

    var body: some View {
        let display = snapshot ?? placeholderSnapshot
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Spending Cadence")
                    .font(.headline)
                if isEmptySnapshot(display) {
                    Text("No expenses yet.")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    cadenceLink(for: display.today)
                    cadenceLink(for: display.week)
                    cadenceLink(for: display.month)
                }
                .padding(.vertical, 2)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .onAppear(perform: reload)
        .onChange(of: appSettingsStore.snapshot) { _ in reload() }
        .onReceive(NotificationCenter.default.publisher(for: .transactionsDidChange)) { _ in
            reload()
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSManagedObjectContextObjectsDidChange, object: context)) { _ in
            reload()
        }
    }

    private func reload() {
        snapshot = transactionsStore.fetchSpendingCadence()
    }

    private var placeholderSnapshot: TransactionsStore.SpendingCadenceSnapshot {
        let now = Date()
        return TransactionsStore.SpendingCadenceSnapshot(
            today: TransactionsStore.SpendingCadenceSnapshot.PeriodTotal(
                label: "Today",
                start: now,
                end: now,
                currentTotal: .zero,
                previousTotal: .zero
            ),
            week: TransactionsStore.SpendingCadenceSnapshot.PeriodTotal(
                label: "This Week",
                start: now,
                end: now,
                currentTotal: .zero,
                previousTotal: .zero
            ),
            month: TransactionsStore.SpendingCadenceSnapshot.PeriodTotal(
                label: "This Month",
                start: now,
                end: now,
                currentTotal: .zero,
                previousTotal: .zero
            )
        )
    }

    private func isEmptySnapshot(_ snapshot: TransactionsStore.SpendingCadenceSnapshot) -> Bool {
        snapshot.today.currentTotal == .zero &&
            snapshot.week.currentTotal == .zero &&
            snapshot.month.currentTotal == .zero
    }

    private func cadenceLink(for period: TransactionsStore.SpendingCadenceSnapshot.PeriodTotal) -> some View {
        NavigationLink {
            TransactionsView(store: transactionsStore, filter: filter(for: period))
        } label: {
            CadenceTile(
                title: period.label,
                total: period.currentTotal,
                previousTotal: period.previousTotal,
                currencyCode: appSettingsStore.snapshot.baseCurrencyCode
            )
        }
        .buttonStyle(.plain)
    }

    private func filter(for period: TransactionsStore.SpendingCadenceSnapshot.PeriodTotal) -> TransactionFilter {
        var filter = TransactionFilter()
        filter.segment = .expenses
        filter.startDate = period.start
        filter.endDate = period.end
        return filter
    }
}

private struct CadenceTile: View {
    let title: String
    let total: Decimal
    let previousTotal: Decimal
    let currencyCode: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(CurrencyFormatter.string(for: total, code: currencyCode))
                .font(.headline)
                .fixedSize(horizontal: true, vertical: false)
            changeBadge
        }
        .padding(12)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
    }

    private var changeBadge: some View {
        let delta = total - previousTotal
        let percentage = previousTotal == .zero ? nil : (delta / previousTotal)
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
        } else if total == .zero {
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
}

#Preview {
    SpendingCadenceCard()
        .environmentObject(AppSettingsStore(persistence: PersistenceController.preview))
        .environmentObject(TransactionsStore(persistence: PersistenceController.preview))
}
