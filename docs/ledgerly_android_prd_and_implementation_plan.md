# Ledgerly Android PRD And Implementation Plan

Derived from iOS committed `HEAD` only.

Source commit: `1f0505ed13821d351ea818a24b8624ff29b3560e`

## 1. Document Purpose

This document defines:
1. A product requirements document (PRD) for Ledgerly Android that mirrors the currently shipped iOS feature set at the source commit above.
2. A concrete implementation plan (no timeline) for building Android with Codex.

This is a parity-first plan. New Android-only features are explicitly out of scope unless listed.

## 2. Product Summary

Ledgerly is an offline-first, net-worth-centered personal finance app with:
1. Multi-currency wallets and base-currency reporting.
2. Transactions with income, expense, and transfer support.
3. Budgets and savings goals.
4. Manual assets, receivables, investments, and liabilities.
5. Optional live investment pricing (crypto and stocks).
6. Backup/import and CSV export.

Core principle: all user financial data lives on-device by default.

## 3. Goals And Non-Goals

### 3.1 Goals

1. Deliver Android feature parity with iOS `HEAD`.
2. Preserve business-rule parity for currency conversion, balances, net worth, budgets, and goals.
3. Keep offline-first behavior for all core workflows.
4. Preserve backup/import compatibility contract semantics.
5. Make optional market data keys user-configurable and non-blocking.

### 3.2 Non-Goals

1. No server sync, account system, or cloud-first architecture.
2. No bank account aggregation integrations.
3. No redesign that changes product behavior before parity.
4. No migration to the unused advanced investment model (InvestmentAccount/HoldingLot UI) in v1 parity.
5. No monthly timeline commitments in this document.

## 4. Current iOS Scope To Mirror

### 4.1 App Shell

1. Onboarding gate based on `hasCompletedOnboarding`.
2. Bottom tabs:
   1. Home
   2. Wallets
   3. Transactions
   4. More

### 4.2 Onboarding

Four-step onboarding:
1. Welcome
2. Base currency selection
3. Exchange mode selection (`official`, `parallel`, `manual`)
4. Summary and finish

On finish:
1. Persist base currency.
2. Persist exchange mode.
3. Mark onboarding complete.

### 4.3 Home Dashboard Widgets

Configurable and reorderable widgets:
1. Net Worth Breakdown
2. Financial Health
3. Expense Breakdown
4. Spending Cadence
5. Income Progress
6. Budgets Summary
7. Goals Summary

Home also includes:
1. Manual entries entry point.
2. Price refresh action for manual investments.

### 4.4 Wallets

1. Wallet CRUD.
2. Wallet fields:
   1. Name
   2. Type
   3. Currency
   4. Starting balance
   5. Current balance
   6. Include in net worth
   7. Icon
3. Grouped display:
   1. Income sources (`WalletKind.income`)
   2. Accounts (all other kinds)

### 4.5 Transactions

1. Create/edit/delete transactions.
2. Types:
   1. Expense
   2. Income
   3. Transfer
3. Filters:
   1. Segment
   2. Wallet
   3. Start date
   4. End date
   5. Search text over notes and wallet name
4. Day-grouped list with section totals.
5. Summary tiles:
   1. This month
   2. Last month
   3. Income
   4. Expenses
6. Category create-from-form support.
7. Detail editor with per-field save/reset and "Zen Edit".

### 4.6 Budgets

1. Monthly budget CRUD by category.
2. Limit amount and budget currency.
3. Month and year selection.
4. Spent calculation from expense transactions in date window.
5. Threshold alert tracking and notifications at:
   1. 50%
   2. 80%
   3. 100%

### 4.7 Goals

1. Goal CRUD.
2. Goal fields:
   1. Name
   2. Target amount
   3. Currency
   4. Current amount
   5. Deadline
   6. Status (`active`/`completed`)
   7. Optional linked wallet
   8. Optional linked category
3. Contribution updates:
   1. Add
   2. Withdraw
4. Completion and reopen actions.
5. Overview metrics and upcoming deadline.

### 4.8 Manual Entries

Sections:
1. Assets
2. Receivables
3. Investments
4. Liabilities

Investment-specific behavior:
1. Crypto or stock type.
2. Coin/ticker identifier.
3. Quantity, cost per unit, contract multiplier.
4. Funding wallet required.
5. Wallet balance adjusted when investment value changes.
6. Optional per-stock manual refresh.
7. P/L display, including converted/base display when possible.

### 4.9 Settings And Utilities

1. Base currency change.
2. Exchange mode change.
3. Notifications toggle.
4. Exchange rate CRUD.
5. Dashboard preferences.
6. Category management.
7. JSON backup export/import.
8. CSV export:
   1. Wallets
   2. Transactions
   3. Budgets
   4. Net worth snapshots
9. Net worth rebuild action (monthly snapshots).

## 5. Data Model Requirements

Android must represent all persisted iOS concepts at parity.

### 5.1 Core Entities

1. `AppSettings`
2. `Category`
3. `Wallet`
4. `Transaction`
5. `MonthlyBudget`
6. `BudgetAlert`
7. `SavingGoal`
8. `ManualAsset`
9. `ManualLiability`
10. `NetWorthSnapshot`

### 5.2 Additional Modeled But Not Mainline UI Entities

These exist in iOS model and should be supported in schema parity for forward compatibility:
1. `InvestmentAccount`
2. `InvestmentAsset`
3. `HoldingLot`
4. `HoldingSale`
5. `PriceSnapshot`

### 5.3 Required Key Fields And Constraints

1. String `identifier` UUID-style field on all major entities.
2. `AppSettings.identifier` unique singleton (`app_settings_singleton`).
3. `Wallet.includeInNetWorth` boolean.
4. `Transaction.isTransfer` boolean.
5. `MonthlyBudget.alert50Sent/alert80Sent/alert100Sent`.
6. `SavingGoal.status`.
7. `ManualAsset` investment metadata fields:
   1. `investmentProvider`
   2. `investmentCoinID`
   3. `investmentSymbol`
   4. `investmentQuantity`
   5. `investmentCostPerUnit`
   6. `investmentContractMultiplier`
   7. `marketPrice`
   8. `marketPriceCurrencyCode`
   9. `marketPriceUpdatedAt`

## 6. Business Rules (Must Match iOS)

### 6.1 Currency Conversion

1. Base currency from settings.
2. Conversion table is manual exchange rates map.
3. `convertToBase(amount, currency)`:
   1. If source currency is base, return amount.
   2. If no rate, return amount unchanged.
   3. Else multiply by rate.
4. `convertFromBase(amount, target)`:
   1. If target is base, return amount.
   2. If no rate or zero rate, return amount unchanged.
   3. Else divide by rate.
5. Base currency change rebases existing rates when possible.
6. If rebase factor unavailable, rates are cleared.

### 6.2 Wallet Balance Mutation Rules

1. Creating transaction updates source wallet:
   1. Expense/transfer: subtract converted wallet amount.
   2. Income: add converted wallet amount.
2. Transfer also credits destination wallet.
3. Editing/deleting transaction replays wallet deltas by reversing previous state then applying new state.
4. Transaction values are converted through base currency for cross-wallet currency adjustments.

### 6.3 Transaction Totals Rules

1. Signed totals:
   1. Expense negative
   2. Income positive
   3. Transfer zero for reporting totals
2. Filters apply via segment + wallet + date + text.
3. Expense breakdown groups by category name or "Uncategorized".

### 6.4 Budget Rules

1. Spent amount = sum expense transactions in budget month/year for budget category.
2. Spent is expressed in budget currency (transaction converted from transaction currency).
3. Threshold flags set once when crossing 50/80/100.
4. Alerts are recorded in `BudgetAlert` and optionally notified when notifications enabled.

### 6.5 Goal Rules

1. Contribution clamps at:
   1. Lower bound `0`
   2. Upper bound `target` when target > 0
2. Status auto-completion when current >= target.
3. Reopen sets status back to active.
4. Wallet-linked goals receive `applyWalletDelta` updates when investment funding wallet balance changes.

### 6.6 Net Worth Rules

Total composition:
1. `walletAssets` = sum included wallet balances converted to base.
2. `manualAssetsTotal` = sum manual assets converted to base.
3. `manualInvestments` = manual assets detected as investment.
4. `receivables` = manual assets where type contains "receiv".
5. `tangibleAssetsNet = max(manualAssetsTotal - manualInvestments - receivables, 0)`.
6. `totalAssets = walletAssets + tangibleAssetsNet + receivables + manualInvestments`.
7. `totalLiabilities` = sum manual liabilities converted to base.
8. `netWorth = totalAssets - totalLiabilities`.
9. `coreNetWorth` and `tangibleNetWorth` derive from include flags.

FX exposure:
1. Split assets/liabilities by base-currency vs foreign-currency.
2. Report foreign asset share and net exposure.

Manual investment performance:
1. Cost basis = quantity * costPerUnit.
2. Current value = stored asset value or fallback cost basis.
3. Performance in base currency.

### 6.7 Net Worth Snapshot Rules (Monthly in HEAD)

1. Snapshot baseline starts Jan 2026.
2. On reload, ensure monthly snapshot if last snapshot older than one month and current date past baseline.
3. Rebuild operation:
   1. Deletes snapshots.
   2. Reconstructs month-by-month from max(baseline, earliest data month).
   3. Uses current FX rates and current manual valuation behavior.
4. Historical rebuild values are approximate by design.

## 7. Market Data Requirements

### 7.1 Optional Integrations

1. CoinGecko for crypto prices (`COINGECKO_API_KEY` optional).
2. Alpha Vantage for stock prices (`ALPHAVANTAGE_API_KEY` optional).
3. Massive ticker search (`MASSIVE_API_KEY` optional).

### 7.2 Behavior

1. App remains fully functional without API keys.
2. Missing keys skip relevant refresh paths.
3. Crypto IDs lowercased.
4. Stock IDs uppercased.
5. Contract multiplier applied to stock quote before valuation.
6. Price refresh updates:
   1. `marketPrice`
   2. `marketPriceCurrencyCode`
   3. `marketPriceUpdatedAt`
   4. `ManualAsset.value` based on quantity

## 8. Backup, Import, And Export Contracts

### 8.1 JSON Backup Contract (`LedgerlyBackup`)

Top-level:
1. `metadata { version, exportedAt }`
2. `categories[]`
3. `wallets[]`
4. `transactions[]`
5. `manualAssets[]`
6. `manualLiabilities[]`
7. `budgets[]`
8. `goals[]`
9. `netWorthSnapshots[]`

Import semantics:
1. Upsert by `identifier`.
2. Category dedupe fallback by semantic signature.
3. Relationship linking by identifier references.
4. Import should refresh all stores on completion.

### 8.2 CSV Export Contract

Exports required:
1. Wallets CSV
2. Transactions CSV
3. Budgets CSV
4. Net-worth snapshots CSV

CSV requirements:
1. Stable headers as in iOS.
2. ISO-8601 date formatting.
3. Proper escaping for commas/quotes/newlines.

## 9. UX Requirements For Android

### 9.1 Navigation

1. Bottom navigation with 4 tabs matching iOS.
2. Nested navigation per tab.
3. Modal/sheet equivalents for create/edit forms.

### 9.2 Visual And Interaction Parity

1. Keep the same screen intent and information hierarchy.
2. Preserve key flows:
   1. Quick add transaction
   2. Wallet CRUD
   3. Manual entries management
   4. Dashboard widget customization
3. Keep chart-based cards:
   1. Expense donut
   2. Net-worth donut
   3. Income bars

### 9.3 Empty States

Must include explicit empty states for:
1. Wallets
2. Transactions
3. Budgets
4. Goals
5. Investments
6. Dashboard when no widgets visible

## 10. Non-Functional Requirements

### 10.1 Offline-First

1. All core CRUD and reporting must work without network.
2. Network is optional for pricing/search only.

### 10.2 Performance

1. Dashboard should remain responsive on large datasets.
2. Use indexed query paths for transaction date/category/wallet filtering.
3. Avoid full in-memory scans where SQL aggregation is sufficient.

### 10.3 Data Integrity

1. All write operations should be transactional.
2. Derived balance and net-worth calculations must be deterministic.
3. Backup import must not corrupt relational references.

### 10.4 Security

1. Store API keys in Android Keystore-backed encrypted storage.
2. Do not transmit local finance content beyond required market symbols.
3. Keep app fully usable when user opts out of all keys.

## 11. Explicit Scope Gaps In iOS HEAD To Preserve

These are in iOS HEAD and should be mirrored as-is:
1. Exchange mode (`official/parallel/manual`) is a setting label with manual-rate backend behavior, not a true multi-provider FX engine.
2. Advanced investment entities (`InvestmentAccount`, `HoldingLot`, etc.) are modeled but not mainline user flow.
3. Net worth snapshot cadence is monthly in committed HEAD.
4. No account authentication and no cloud sync workflow.

## 12. Android Technical Architecture

## 12.1 Stack

1. Kotlin
2. Jetpack Compose
3. Room
4. Kotlin Coroutines + Flow
5. WorkManager (for optional background tasks)
6. DataStore for lightweight settings if needed, but primary settings should stay in Room for parity with singleton model
7. MPAndroidChart or Compose charts equivalent

### 12.2 Module Layout

1. `app` (navigation, DI, app shell)
2. `core-model` (domain models, value objects, enums)
3. `core-db` (Room entities, DAOs, migrations)
4. `core-data` (repositories, mappers, services)
5. `feature-onboarding`
6. `feature-home`
7. `feature-wallets`
8. `feature-transactions`
9. `feature-budgets`
10. `feature-goals`
11. `feature-manual-entries`
12. `feature-settings`
13. `feature-export-import`

### 12.3 Layering

1. UI layer: Compose screens + state holders (ViewModel).
2. Domain layer: use-cases/services for calculations.
3. Data layer: repository orchestration over Room + network clients.
4. Infra layer: serialization, background work, notifications, key storage.

## 13. Implementation Plan (No Timeline)

### 13.1 Workstream A: Foundation

1. Initialize Android project and module structure.
2. Set up DI and app-level navigation shell.
3. Create base design tokens and reusable input components:
   1. Decimal input field
   2. Currency picker
   3. Generic list/detail scaffolds

Deliverable:
1. App starts with placeholder tabs and DI configured.

### 13.2 Workstream B: Persistence And Domain Model Parity

1. Implement Room schema for all parity entities.
2. Add mappers between Room and domain models.
3. Seed defaults:
   1. App settings singleton
   2. Default categories
4. Implement category dedupe-on-start logic compatible with iOS behavior.

Deliverable:
1. Database boots cleanly and parity entities are persisted/retrieved.

### 13.3 Workstream C: Core Calculation Services

1. Currency converter service parity.
2. Transaction aggregation services:
   1. Expense breakdown
   2. Spending cadence
   3. Cash flow
   4. Income progress
3. Net-worth service parity with monthly snapshot behavior.
4. Goal and budget computation services.

Deliverable:
1. Unit-tested calculation layer with deterministic parity outputs.

### 13.4 Workstream D: Wallets + Transactions

1. Wallet list/add/edit/delete.
2. Transaction list/filter/detail/create.
3. Category picker and category creation form.
4. Wallet balance mutation logic parity for create/update/delete/transfer.

Deliverable:
1. End-to-end wallet and transaction workflows with parity math.

### 13.5 Workstream E: Dashboard

1. Home screen with widget ordering from settings.
2. Implement cards:
   1. Net worth breakdown
   2. Financial health
   3. Expense breakdown
   4. Spending cadence
   5. Income progress
   6. Budget summary
   7. Goals summary
3. Dashboard preferences screen for reorder/hide/add.

Deliverable:
1. Functional customizable dashboard matching iOS behavior.

### 13.6 Workstream F: Budgets + Goals

1. Budget CRUD and detail.
2. Budget alert thresholds and alert logs.
3. Goal CRUD, contribution sheet, detail metrics, status transitions.
4. Goal reminder notifications (deadline-based).

Deliverable:
1. Full planning flows and notification hooks.

### 13.7 Workstream G: Manual Entries + Investments

1. Assets/receivables/investments/liabilities sections.
2. Investment form with crypto/stock branches and ticker search integration.
3. Wallet-funding adjustment logic parity.
4. Stock/crypto refresh with optional keys and graceful skip behavior.

Deliverable:
1. Complete manual entry management and investment P/L parity.

### 13.8 Workstream H: Settings + Data Utilities

1. Settings screen parity sections:
   1. Base currency
   2. Exchange mode
   3. Notifications
   4. Exchange rates
   5. Dashboard preferences
   6. Categories
2. JSON backup export/import implementation.
3. CSV exports for all four datasets.
4. Net-worth monthly rebuild action.

Deliverable:
1. Fully functional utilities and data portability.

### 13.9 Workstream I: Hardening And QA

1. Add instrumentation tests for critical flows.
2. Add snapshot tests or golden tests for calculation outputs.
3. Add migration tests for Room schema evolution.
4. Add regression suite for JSON import/export compatibility.
5. Validate app behavior with no network and no API keys.

Deliverable:
1. Release-ready parity build.

## 14. Parity Acceptance Criteria

Android v1 is accepted when:
1. Every iOS HEAD major flow listed in section 4 is implemented.
2. Calculation parity holds for:
   1. Wallet balances
   2. Dashboard totals
   3. Budget spent/thresholds
   4. Goal progress and status
   5. Net-worth totals and snapshot rebuild
3. Backup import from Android-generated files works round-trip.
4. App remains usable offline end-to-end for core flows.
5. Missing API keys do not block any non-market-data feature.

## 15. Suggested Codex Execution Order

Use this order to start implementation:
1. Foundation + Room schema + repositories.
2. Currency/transaction/net-worth calculation services with tests.
3. Wallets and transactions UI flows.
4. Dashboard widgets and preferences.
5. Budgets and goals.
6. Manual entries and market data integrations.
7. Backup/import/export and settings.
8. Hardening and parity verification.

## 16. Notes For Future Iterations (Post-Parity)

After parity, candidate enhancements:
1. True FX provider strategy behind exchange modes.
2. Dedicated investment accounts and lot-level UI.
3. Background snapshot job cadence improvements.
4. Optional encrypted backup files.
5. Optional sync architecture.

