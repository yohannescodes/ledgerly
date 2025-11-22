# Ledgerly

Ledgerly is a SwiftUI + Core Data personal finance app that keeps every data point on-device. It helps you track wallets, transactions, budgets, goals, manual assets/liabilities, investments, and your overall financial health with live currency conversions and analytics.

## Table of Contents
1. [Architecture](#architecture)
2. [Feature Tour](#feature-tour)
3. [Currency & Exchange Rates](#currency--exchange-rates)
4. [Running the App](#running-the-app)
5. [Data Model Overview](#data-model-overview)
6. [Extending the App](#extending-the-app)

---

## Architecture
- **SwiftUI-first UI** with tab-based navigation (`MainTabView`), dedicated views per module, and sheet-driven flows for create/edit actions.
- **Core Data** persistence managed by `PersistenceController` and domain-specific stores (`WalletsStore`, `TransactionsStore`, `InvestmentsStore`, etc.)
- **Combine bindings** to propagate changes: stores publish through `@Published`, and the Net Worth dashboard listens via notifications (wallets/investments) to remain real time.
- **Currency conversion** is centralized in `CurrencyConverter`, using base currency + custom rates defined in Settings.
- **PriceService** can pull quotes from AlphaVantage/CoinGecko (when API keys are supplied) and also provides deterministic local prices for offline/demo usage.

## Feature Tour
### Onboarding
- Guides users through choosing a base currency, exchange-rate mode (official/parallel/manual), cloud-sync preference, and summary confirmation.

### Home
- **Financial Health** card: displays `(Assets + Investments + Wallets + Receivables) - Liabilities` with breakdowns (stocks/crypto, receivables, etc.).
- **Net Worth Trend** chart: shows real-time net-worth snapshots with annotations and quick range tabs.
- Links to manage manual assets, receivables, and liabilities.

### Wallets
- Create income/checking/savings/crypto/etc. wallets, each with its own currency and icon.
- Balances update instantly after transactions, transfers, or investment funding/withdrawals.
- Swipe to delete wallets, open forms to edit, and track manual receivables/liabilities in the shared manual entries screen.

### Transactions
- Fully featured ledger:
  - Summary tiles (this month, last month, income, expenses).
  - Sectioned list grouped by date.
  - Advanced filters (segment, wallet, date range, search) with a dedicated sheet.
  - Detailed transaction view with delete action.
  - Add transactions with a form supporting expenses/income/transfers, wallet selection, currency picker, categories, and notes.

### Budgets & Goals
- Budgets tab shows monthly category spend vs. limits (alerts integrate with the notifications store).
- Goals tab lists savings goals with progress bars and deadlines.

### Investments
- Users can add/remove accounts (brokerage, exchange, retirement, etc.) each with its own currency.
- Holdings support custom currency for cost/unit, funding from wallets, and automatic price refresh. Selling or deleting a holding adjusts wallets/net worth.
- Account detail view shows market value, cost basis, realized sales, and wallet transfer helpers. Holdings list supports selling or deleting via swipe actions.

### Manual Entries
- Assets, receivables, and liabilities can be logged with custom currencies and delete/edit flows.
- Receivables automatically feed the Financial Health calculation.

### Settings
- Base currency, exchange mode, cloud sync, notifications, and dashboard layout.
- **Exchange Rates** section lets users add/edit/delete custom FX rates using the same currency picker used elsewhere.
- CSV export, JSON backup/restore, and dashboard customization live here.

## Currency & Exchange Rates
- Base currency is selected during onboarding (can be changed in Settings).
- Exchange rates are user-defined: add a currency (e.g., USD) and supply how much 1 unit equals in your base currency (e.g., USD→ETB = 55).
- `CurrencyConverter` applies these rates when calculating wallet balances, manual assets/liabilities, transactions, and investment holdings. Net Worth, Financial Health, and transaction summaries update immediately when rates change.

## Running the App
1. **Requirements**: Xcode 15+, iOS 17 simulator/device.
2. **Clone & Open**: `open ledgerly.xcodeproj`.
3. **APIs (optional)**: set the `ALPHAVANTAGE_API_KEY` environment variable in the scheme for real stock quotes; crypto uses CoinGecko (no key required by default).
4. **Build/Run**: Press ⌘R to launch. All data is stored locally in Core Data; there’s no demo-seeding, so add your own wallets/investments/transactions.

## Data Model Overview
- `Wallet`: name, type (income/checking/etc.), base currency, balances, include-in-net-worth flag.
- `Transaction`: amount, direction, currency, wallet, category, notes, date, converted base amount.
- `ManualAsset` / `ManualLiability`: assets (tangible/receivable) and debts with include-in-core/tangible flags.
- `InvestmentAccount` / `InvestmentAsset` / `HoldingLot`: accounts, assets (stock/crypto), holding lots with cost basis and sales history.
- `PriceSnapshot`: cached price history per investment asset.
- `MonthlyBudget`, `SavingGoal`, `NetWorthSnapshot`, `AppSettings`, `Category`, `Wallet` helper models.

## Extending the App
- **Integrations**: tie into bank APIs or CSV import/export to populate wallets and transactions automatically.
- **Analytics**: add sector allocation, risk metrics, alerts for price swings, or AI-driven insights per PRD ideas.
- **Sync**: CloudKit/iCloud support can be toggled later; currently the app is offline-first.
- **Automations**: recurring transactions, scheduled transfers, and reminders can build on the existing stores.

Ledgerly is designed to be privacy-first and extremely transparent—every change updates the home dashboard immediately, exchange rates are user-controlled, and all heavy calculations stay on-device. Contributions that keep those principles are welcome!
