# Ledgerly

Ledgerly is an offline-first SwiftUI personal finance app that keeps every record on-device while still giving you wallets, budgets, goals, manual assets, liabilities, investments, and currency-aware analytics.

## Highlights
- SwiftUI interface with Core Data powered stores for wallets, transactions, budgets, goals, and net-worth widgets.
- Offline-friendly currency and investment pricing with manual overrides plus optional CoinGecko refreshes when a network is available.
- Rich dashboard that surfaces net worth trends, expense breakdowns, and progress cards the moment data changes.
- Full CRUD flows for wallets, transactions (including transfers), manual entries, budgets, and savings goals, each with dedicated forms and sheets.
- Built-in settings page for base currency, exchange-rate profiles, dashboard preferences, notifications, and JSON backup/restore.

## Table of Contents
1. [Architecture](#architecture)
2. [Feature Tour](#feature-tour)
3. [Currency & Exchange Rates](#currency--exchange-rates)
4. [Running the App](#running-the-app)
5. [Data Model Snapshot](#data-model-snapshot)
6. [Extending Ledgerly](#extending-ledgerly)
7. [Screenshots](#screenshots)

## Architecture
Ledgerly follows a simple but explicit layering that keeps the UI reactive while persisting everything in Core Data.

### UI Layer
- `ledgerlyApp.swift` wires up shared stores (`AppSettingsStore`, `WalletsStore`, etc.) as `EnvironmentObject`s so every view sees the same data.
- Routing starts in `ContentView` which flips between the multi-step onboarding flow and the tab bar (`MainTabView`).
- Each tab owns its own navigation stack (`HomeOverviewView`, `WalletsView`, `TransactionsView`, `MoreHubView`) to keep state isolated and deep links simple.
- Swift Charts drive dashboard widgets (net worth history, expense pie chart, income bar chart) for fast, native data viz.

### Data & Stores
- `PersistenceController` exposes the Core Data stack plus helper contexts for background writes.
- Store objects inside `/Data` (wallets, transactions, budgets, goals, net-worth, settings) fetch on background queues, expose `@Published` snapshots, and broadcast `NotificationCenter` updates for cross-feature synchronization.
- Models inside `/Models` wrap Core Data entities with helpers for formatting, derived values, and static fixtures for previews.

### Services
- `NetWorthService` aggregates wallets, manual entries, and liabilities into live net-worth totals and snapshots.
- `PriceService` and `ManualInvestmentPriceService` maintain deterministic local prices and optional remote quotes (CoinGecko or custom clients) for manual investments.
- `DataBackupService` and `DataExportService` create JSON backups, import payloads, and refresh stores after restores.
- `BudgetAlertService` and `GoalReminderService` hook into `UNUserNotificationCenter` when alerts are enabled.

### Offline Strategy
- Everything (transactions, exchange rates, price snapshots) is stored locally, so every screen can render synchronously from disk.
- Derived data (net worth totals, expense summaries) is recalculated after each mutation and cached for the dashboard.
- Settings let you keep CloudKit disabled; the plumbing is Core Data only so nothing leaves the device without an explicit export.

## Feature Tour

### Onboarding
- Four interactive steps (`Welcome → Base Currency → Exchange Mode → Summary`) walk users through the initial choices before unlocking the tabs.
- Exchange mode cards explain official, parallel, and manual behaviors, and the chosen values seed the settings store.

### Home Dashboard
- Widget order is user-defined through `DashboardPreferencesView` and stored inside `AppSettingsSnapshot`.
- Net Worth History: sparkline built from `NetWorthStore.liveTotals`, includes tangible vs volatile breakdowns.
- Expense Breakdown: pie chart with 30/90 day filters plus trend badges.
- Income Progress: trailing 12 months bar chart that highlights streaks.
- Budget & Goal summaries summarize top limits and savings progress, and a manual entries quick link keeps assets/liabilities handy.

### Wallets
- Wallets are grouped by type (income sources vs accounts) with icons pulled from `WalletKind`.
- Modal form supports naming, type selection, currency picker, balances, net-worth inclusion, and custom icons.
- Edit sheets reuse the same form, include delete actions, and reload the net-worth store once dismissed.

### Transactions
- Scrollable summary tiles show this month, last month, income, and expense totals based on the base currency.
- Segmented control toggles between all, income, expenses, and transfers while filters support wallet, date range, and free text search.
- Sectioned list groups entries by date with per-day totals; tapping opens a full detail sheet with delete/duplicate actions.
- Creation form handles expense, income, and transfer flows (wallet to wallet) with currency picker, categories, tags, and notes.

### Budgets
- Monthly budgets live in `/Data/BudgetsStore.swift` and load into `BudgetsView` with progress meters.
- Detail screens show activity, alerts triggered, and let you jump into edit mode.
- Form supports limit amount, currency, alert thresholds, and linking to whatever category you track.

### Goals
- Goals list progress bars, deadlines, and target amounts.
- Detail view shows contributions, available actions (fast add, edit, delete), and uses reminder services if notifications are on.
- Contribution sheet can pull funds from wallets or log manual top-ups.

### Manual Entries
- Assets, receivables, investments, and liabilities share a dedicated list with Core Data fetch requests scoped per type.
- Investment entry sheet captures symbol, quantity, cost basis, and provider kind (stock vs crypto) so pricing services know how to refresh it.
- Any change refreshes `NetWorthStore` immediately so the dashboard stays in sync.

### Settings & Utilities
- Settings hub (`SettingsDebugView`) lets you manage base currency, exchange mode, notification toggle, dashboard preferences, and per-currency manual rates.
- Exchange rate sheet supports add/edit/delete with validation and uses the same picker control seen in onboarding.
- Backup & Restore buttons export/import JSON payloads through the system share sheet and file importer.

## Currency & Exchange Rates
- Base currency lives in `AppSettings` and drives all conversions, reports, and dashboard tiles.
- Exchange modes: `official`, `parallel`, `manual`. Each wallet can still hold its own currency; conversions pass through the base currency via `CurrencyConverter`.
- Manual overrides are stored per currency code and surfaced in Settings for quick edits.
- `ManualInvestmentPriceService` tries to fetch fresh CoinGecko prices (crypto) and leaves hooks for other providers; `PriceService` generates deterministic local prices when offline.
- Every transaction and investment records the actual rate snapshot that was used so history remains reproducible.

## Running the App
1. **Requirements**: Xcode 15.4 or newer, iOS 17 simulator or device, Swift 5.9 toolchain.
2. `git clone` this repository and open `ledgerly.xcodeproj` in Xcode.
3. Select the `ledgerly` scheme and your preferred simulator (the sample screenshots use iPhone 16 Pro Max).
4. Build & run. The onboarding flow will guide you through base currency and exchange-mode selection before showing the dashboard.
5. Optional: if you want live CoinGecko prices, add `COINGECKO_API_KEY` to the scheme environment (otherwise deterministic local prices are used).

### Troubleshooting
- If Core Data migrations fail, delete the app from the simulator and rerun (no external dependencies to clean up).
- Importing a backup replaces wallets, budgets, goals, and manual entries; after import, stores trigger `.reload()` automatically.

## Data Model Snapshot
| Domain | Entities / Models | Notes |
| --- | --- | --- |
| Configuration | `AppSettings`, `ExchangeRateProfile`, `ExchangeRate`, `ChangeLog` | Base currency, exchange mode, custom rates, and audit logging. |
| Wallets & Categories | `Wallet`, `Category`, `Tag` plus `WalletModel`, `Category+Helpers` | Wallets keep balances, icons, types, and net-worth inclusion flags. |
| Transactions | `Transaction`, `TransactionSplit`, `RecurringMetadata` | Unified ledger with support for transfers and per-entry rate snapshots. |
| Investments | `ManualAsset` (investment kind), `InvestmentAsset`, `HoldingLot`, `PriceSnapshot` | Manual holdings with price refresh hooks and deterministic offline fallbacks. |
| Budgets & Goals | `MonthlyBudget`, `BudgetAlert`, `SavingGoal` | Monthly limits with alert thresholds and savings milestones. |
| Net Worth | `ManualAsset`, `ManualLiability`, `NetWorthSnapshot` | Aggregated monthly snapshots feeding the dashboard cards. |

## Extending Ledgerly
- **Hook up live providers**: implement `MarketDataClient` for Alpha Vantage or Finnhub and inject it into `PriceService` to replace pseudo prices.
- **Cloud sync**: toggle CloudKit on `NSPersistentContainer` and use `ChangeLog` to help resolve conflicts when sync is enabled.
- **Widgets & Siri**: expose `NetWorthStore` data to WidgetKit or App Intents for glanceable metrics.
- **Automations**: add Shortcuts actions that post transactions or transfer between wallets without opening the app.

## Screenshots
| Home | Wallets | Transactions |
| --- | --- | --- |
| ![Home](ledgerly/Screenshots/Simulator%20Screenshot%20-%20iPhone%2016%20Pro%20Max%20-%202025-11-23%20at%2015.33.16.png) | ![Wallets](ledgerly/Screenshots/Simulator%20Screenshot%20-%20i| ![Home](ledgerly/Screenshots/Simulator%20Screenshot%20-%20iPhone%2016%20Pro%20Max%20-%202025-11-23%20at%2015.33.16.png) | ![Wallets](ledgerly/Screenshots/Simulator%20Screenshot%20-%20iPhone%2016%20Pro%20Max%20-%202025-11-23%20at%2015.33.51.png) | ![Transactions](ledgerly/Screenshots/Simulator%20Screenshot%20-%20iPhone%2016%20Pro%20Max%20-%202025-11-23%20at%2015.33.55.png) |
| Budgets | Goals | Manual Entries |
| --- | --- | --- |
| ![Budgets](ledgerly/Screenshots/Simulator%20Screenshot%20-%20iPhone%2016%20Pro%20Max%20-%202025-11-23%20at%2015.34.12.png) | ![Goals](ledgerly/Screenshots/Simulator%20Screenshot%20-%20iPhone%2016%20Pro%20Max%20-%202025-11-23%20at%2015.34.17.png)| ![Manual Entries](ledgerly/Screenshots/Simulator%20Screenshot%20-%20iPhone%2016%20Pro%20Max%20-%202025-11-23%20at%2015.34.08.png) |

| Settings | Dashboard Preferences | Exchange Rates |
| --- | --- | --- |
| ![More](ledgerly/Screenshots/Simulator%20Screenshot%20-%20iPhone%2016%20Pro%20Max%20-%202025-11-23%20at%2015.33.59.png) | ![Dashboard Preferences](ledgerly/Screenshots/Simulator%20Screenshot%20-%20iPhone%2016%20Pro%20Max%20-%202025-11-23%20at%2015.33.43.png) | ![Settings](ledgerly/Screenshots/Simulator%20Screenshot%20-%20iPhone%2016%20Pro%20Max%20-%202025-11-23%20at%2015.34.25.png) |
