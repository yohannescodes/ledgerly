# Feature Design: Spending Cadence Insights (Daily, Weekly, Monthly)

## Summary
Add a new dashboard insight that shows how much a user spends per day, per week, and per month using the base currency, with quick comparisons to the previous period and fast access to the underlying transactions.

## Goals
- Show "Today", "This Week", and "This Month" expense totals at a glance on the dashboard.
- Provide lightweight trend context (delta and percent vs previous period).
- Respect the app base currency and exchange-rate settings just like existing summaries.
- Make it easy to jump to filtered expense transactions for each period.

## Non-Goals
- Budget forecasting, alerts, or push notifications.
- Category or merchant breakdowns (handled by existing Expense Breakdown widget).
- Historical charts beyond the immediate comparisons.

## UX and Surface Area
- **Home dashboard widget**: Add a new card titled "Spending Cadence".
  - Three compact tiles in a single row: "Today", "This Week", "This Month".
  - Each tile shows:
    - Total expense amount in base currency.
    - A small delta badge (arrow + percent) vs previous period.
  - Tapping a tile routes to `TransactionsView` with filters:
    - Segment = Expenses
    - Date range = corresponding period
- **Dashboard preferences**: Add "Spending Cadence" to `DashboardWidget` and allow reordering/hide.
- **Empty state**: If there are no expense transactions in the range, show "No expenses yet" and a muted 0 value.

## Data and Calculations
All values are derived from expense transactions only (`direction == "expense"`).

**Period definitions (locale-aware):**
- Day: `startOfDay(now)` to `now`
- Week: `dateInterval(of: .weekOfYear, for: now)` to `now`
- Month: `dateInterval(of: .month, for: now)` to `now`

**Previous period definitions:**
- Day: `startOfDay(now) - 1 day` to `startOfDay(now)`
- Week: immediately preceding week interval
- Month: immediately preceding month interval

**Aggregations:**
- Sum expenses in each period using base currency conversion.
- Percent change is `delta / previousTotal` when previousTotal > 0.

## Currency Handling
- Use `CurrencyConverter` initialized from `AppSettings` to convert each transaction into base currency.
- Display values in `AppSettings.baseCurrencyCode`.
- When a currency rate is missing, follow existing behavior: fall back to the raw amount (same approach as current summaries).
- Recalculate totals when the base currency or rates change.

## Data Model and Storage
- No new Core Data entities or fields required.
- Add a new data loader in `TransactionsStore` that returns a `SpendingCadenceSnapshot` value object.

Suggested shape:
```
struct SpendingCadenceSnapshot {
    struct PeriodTotal {
        let label: String
        let start: Date
        let end: Date
        let currentTotal: Decimal
        let previousTotal: Decimal
    }
    let today: PeriodTotal
    let week: PeriodTotal
    let month: PeriodTotal
}
```

## Refresh and Performance
- Compute cadence on demand (similar to existing widgets) using viewContext fetches.
- Use date-range predicates to keep fetch sizes small.
- If transaction volume grows, consider a future optimization to pre-aggregate daily totals.

## Edge Cases
- Transactions at boundaries: use `Calendar.current` in the user's time zone.
- No previous period data: show "--" for percent or a neutral badge.
- Expenses recorded in multiple currencies: rely on base conversion as used elsewhere.

## Success Criteria
- Dashboard shows daily/weekly/monthly expense totals within 1 second of opening.
- Values match the Transactions list totals for the same period and base currency.
- Changing base currency updates the widget consistently with other features.
