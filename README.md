# ledgerly

ledgerly is an offline-first SwiftUI personal finance app that keeps data on-device while providing wallets, transactions, budgets, goals, manual assets, liabilities, and investment tracking. Reports normalize to a base currency with manual exchange rates, and optional live price refresh for crypto and stocks. <br>
<a href="https://www.producthunt.com/products/github-224?embed=true&utm_source=badge-featured&utm_medium=badge&utm_source=badge-ledgerly" target="_blank"><img src="https://api.producthunt.com/widgets/embed-image/v1/featured.svg?post_id=1041480&theme=dark&t=1764162628406" alt="ledgerly - a&#0032;net&#0045;worth&#0045;centered&#0032;expense&#0032;tracker&#0032;app | Product Hunt" style="width: 250px; height: 54px;" width="250" height="54" /></a>

## Contributing
Read `CONTRIBUTING.md` for collaboration guidelines, coding standards, and the review checklist.

## Highlights
- Offline-first Core Data storage with manual JSON backup and restore.
- Customizable dashboard with reorderable widgets for net worth, financial health, expense mix, spending cadence, and income progress.
- Multi-currency wallets with base-currency reporting and manual FX overrides.
- Fast transaction capture with transfers, categories, filters, and a detail editor built for quick edits.
- Manual entries for assets, receivables, investments, and liabilities with wallet funding and profit tracking.
- Budget alerts and goal reminders driven by system notifications.

## Table of Contents
1. [Architecture](#architecture)
2. [Feature Tour](#feature-tour)
3. [Currency & Exchange Rates](#currency--exchange-rates)
4. [Running the App](#running-the-app)
5. [Data Model Snapshot](#data-model-snapshot)
6. [Extending ledgerly](#extending-ledgerly)
7. [Screenshots](#screenshots)

## Architecture
ledgerly follows a layered SwiftUI architecture centered around Core Data and observable stores.

### UI Layer
- `ledgerlyApp.swift` wires shared stores (`AppSettingsStore`, `WalletsStore`, etc.) as `EnvironmentObject`s.
- `ContentView` switches between the multi-step onboarding flow and the main tab UI.
- The tab bar hosts `HomeOverviewView`, `WalletsView`, `TransactionsView`, and `MoreHubView`.
- Swift Charts powers the expense donut and income progress charts.

### Data & Stores
- `PersistenceController` owns the Core Data stack and background contexts.
- Store objects inside `ledgerly/Data` map Core Data entities into `@Published` models and handle background writes.
- Wallet updates broadcast through `NotificationCenter` so net worth and dashboards refresh automatically.

### Services
- `NetWorthService` calculates totals, monthly snapshots, FX exposure, and manual investment performance.
- `ManualInvestmentPriceService` refreshes crypto prices via CoinGecko and stock quotes via Alpha Vantage.
- `BudgetAlertService` and `GoalReminderService` schedule notification alerts.
- `DataBackupService` exports and imports full JSON backups.

### Offline Strategy
- Everything is stored locally in Core Data; no network is required for core tracking flows.
- FX rates are manual; when a rate is missing, amounts stay in their native currency.
- Live prices and ticker search are optional and only used when API keys are configured.
- Backups are manual JSON exports through the system share sheet.

## Feature Tour

### Onboarding
- Four steps: Welcome, Base Currency, Exchange Mode, Summary.
- Exchange mode is stored as a preference and can be adjusted later in Settings.

### Home Dashboard
- Card-based dashboard with reorderable widgets managed in Dashboard Preferences.
- Net Worth Breakdown: donut segments for wallets, tangible assets, receivables, investments, and liabilities plus delta vs last snapshot.
- Financial Health: 7D/30D/90D cash flow, liquidity share and ratio, investment profit, and FX exposure with commentary.
- Expense Breakdown: category donut with 7D/30D/90D ranges and change badges.
- Spending Cadence: Today/This Week/This Month tiles with delta badges that link to filtered transactions.
- Income Progress: yearly bar chart with month selection and previous-year navigation.
- Budget and Goals summaries surface the top 3 items, and a toolbar action opens manual entries or refreshes prices.

### Wallets
- Wallets are grouped into Income Sources and Accounts based on wallet kind.
- Add and edit flows include name, type, currency, balances, net worth inclusion, and an icon picker.
- Swipe to delete or tap to edit details.

### Transactions
- Summary tiles highlight this month, last month, income, and expense totals in the base currency.
- Segmented control switches between all, expenses, income, and transfers; filters include wallet, date range, and notes or wallet search.
- Entries are grouped by day with per-day totals; rows show base amounts plus native amounts when currencies differ.
- Creation form supports transfers, category creation, currency selection, and notes.
- Detail view uses expandable sections with per-field Save/Reset plus a "Zen Edit" mode to keep all editors open.

### Budgets
- Monthly budgets by category with limit amounts and month/year selection.
- Detail view shows spend vs limit with progress bars.
- Alerts fire at 50/80/100 percent when notifications are enabled.

### Goals
- Overview card summarizes active vs completed, average progress, and the next deadline.
- Filter active/completed/all goals with progress bars and due-date labels.
- Detail view shows progress, remaining amount, monthly target math, and timeline.
- Contributions support add or withdraw, and goals can link to wallets and categories for auto-updates.

### Manual Entries
- Separate sections for assets, receivables, investments, and liabilities with sheet-based add/edit.
- Investment form supports crypto or stock, ticker search suggestions, contract multipliers, and a funding wallet that adjusts balances.
- Holdings show cost basis, profit/loss, and original currency values when converted.
- Price refresh pulls CoinGecko for crypto (optional API key) and Alpha Vantage for stocks (requires key).

### Settings & Utilities
- Base currency, exchange mode, notifications, and manual FX rates in "Dashboard & Settings".
- Dashboard preferences for reordering or hiding widgets.
- JSON backup export/import plus a net worth rebuild option (recalculates from Jan 2026 using current rates).

## Currency & Exchange Rates
- The base currency drives dashboards, summaries, and net worth totals.
- Each wallet keeps its own currency; conversions pass through the base currency via `CurrencyConverter`.
- Exchange mode (official/parallel/manual) is stored as a preference; manual rates are editable per currency.
- Missing rates fall back to the original amount rather than blocking calculations.
- Transactions store both native amounts and base conversions for reproducible reports.

## Running the App
1. **Requirements**: Xcode 15.4 or newer, iOS 17 simulator or device, Swift 5.9 toolchain.
2. `git clone` this repository and open `ledgerly.xcodeproj` in Xcode.
3. Select the `ledgerly` scheme and your preferred simulator (the sample screenshots use iPhone 16 Pro Max).
4. Build and run. The onboarding flow guides you through base currency and exchange mode selection before showing the dashboard.
5. Optional keys (set in the scheme environment):
   - `COINGECKO_API_KEY` for higher CoinGecko rate limits.
   - `ALPHAVANTAGE_API_KEY` for stock price refresh.
   - `MASSIVE_API_KEY` for stock ticker search suggestions.

### Troubleshooting
- If Core Data migrations fail, delete the app from the simulator and rerun.
- Importing a backup replaces wallets, budgets, goals, and manual entries; stores reload automatically.

## Data Model Snapshot
| Domain | Entities / Models | Notes |
| --- | --- | --- |
| Configuration | `AppSettings` | Base currency, exchange mode, notifications, dashboard order, manual FX rates. |
| Wallets & Categories | `Wallet`, `Category` | Wallet types, balances, icons, and income/expense categories. |
| Transactions | `Transaction` | Unified ledger with transfers, base conversions, and notes. |
| Budgets | `MonthlyBudget`, `BudgetAlert` | Monthly limits with notification thresholds. |
| Goals | `SavingGoal` | Targets, deadlines, status, wallet/category links. |
| Manual Entries | `ManualAsset`, `ManualLiability` | Assets, receivables, investments, and liabilities. |
| Net Worth | `NetWorthSnapshot` | Monthly aggregates and notes. |
| Investments (future) | `InvestmentAccount`, `InvestmentAsset`, `HoldingLot`, `HoldingSale`, `PriceSnapshot` | Model scaffolding not yet surfaced in the UI. |
| Misc | `Item` | Template stub, unused in the app. |

## Extending ledgerly
- Plug in new market data providers by adapting `ManualInvestmentPriceService` or `MarketDataClient`.
- Add CSV exports using `DataExportService` or surface it in Settings.
- Enable CloudKit by swapping `PersistenceController` to `NSPersistentCloudKitContainer`.
- Build widgets or App Intents on top of `NetWorthStore` and `TransactionsStore`.

# COMING SOON: DEMO VIDEO
[Yohannes Haile](https://x.com/IBYohannes), 2026 
