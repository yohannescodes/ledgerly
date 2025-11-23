# Ledgerly Phase 2 – Transactions, Income & Categories

## 1. Objectives
1. Deliver full CRUD for expense/income transactions with category/tag filtering, multi-currency conversion, and summaries.
2. Support wallet balance updates, transfers, and recurring income metadata using the existing exchange-rate engine.
3. Lay UI groundwork for Transactions tab (list, filters, detail sheet) and tie it into the onboarding-driven settings.

## 2. Scope Review
- **Wallets**: persistent balances per wallet currency; conversions rely on global base currency.
- **Transactions**: includes expenses, income, transfers, and splits.
- **Categories**: custom, color/icon-coded, plus optional parent/child.
- **Income recurrence**: metadata for salary/freelance flows; autopost (optional) stored but not yet automated.
- **Summaries**: daily/weekly/monthly totals by wallet/category; minimal charts via Swift Charts stub.*

\*Charts deferred unless time remains after CRUD + filtering.

## 3. Data Model Additions
- `Wallet`: fields from Phase 0 doc now added to Core Data model.
- `Category`: `id`, `type`, `name`, `colorHex`, `iconName`, `parent`, `sortOrder`.
- `Tag`: `name`, `colorHex` (optional), many-to-many with `Transaction` via `TransactionTag` join.
- `Transaction`: id (UUID), direction, amount, currencyCode, convertedAmountBase, date, notes, attachments, `wallet`, `category`, `exchangeProfileUsed`, `exchangeRateValue`, `isTransfer`, `counterpartyWallet`, `createdAt`, `updatedAt`.
- `TransactionSplit`: optional children for envelope budgets.
- `RecurringMetadata`: frequency, start/end, nextRunDate, autoPost flag.

**Implementation Steps**
1. Update `.xcdatamodeld` to add these entities/relationships.
2. Regenerate NSManagedObject subclasses or use manual classes via `@NSManaged` extensions.
3. Extend `PersistenceController.seedDefaultsIfNeeded()` to create default wallets/categories for previews.

## 4. Repository & Services Plan
- `WalletRepository` (actor): fetch wallets, create, update balances after transactions.
- `CategoryRepository`: list categories by type, support CRUD, maintain sort order.
- `TransactionRepository`: create/update/delete transactions, handle conversion via `ExchangeRateService` (stub now, real later), compute summaries.
- `TransactionFilter` struct: holds wallet, date range, category, tag, text search.
- `TransactionSummaryService`: returns aggregated totals for list header + charts; uses `NSExpressionDescription` queries to avoid fetching entire dataset.
- `RecurringTransactionScheduler`: background actor storing metadata; autopost stubbed until Phase 3.

## 5. UI / UX Deliverables
1. **Transactions Tab shell**
   - segmented control for Expenses / Income / Transfers.
   - list grouped by date with total per day.
   - swipe actions: delete/duplicate.
   - filter button showing sheet with wallet/category/tag/date pickers.
2. **Add Transaction Flow**
   - presented as bottom sheet (form) with amount keypad, wallet picker, date picker, category grid, notes, attachments.
   - currency conversion label using exchange engine + warnings for stale rates.
3. **Transaction Detail**
   - read-only view with edit button, showing conversion snapshot, tags, recurrence info.
4. **Category Manager**
   - accessible via Settings and Add Transaction form; allows add/edit/delete categories (with icon/color pickers).
5. **Empty States**
   - guided cards encouraging user to add first wallet/transaction.

## 6. Implementation Checklist
1. Update Core Data model and managed objects for wallets/categories/transactions.
2. Build repositories + Combine publishers for wallets and transactions.
3. Implement `TransactionsViewModel` powering the Transactions tab (list + filters + summary).
4. Create SwiftUI components: `TransactionRowView`, `TransactionFilterSheet`, `TransactionFormView`, `CategoryPickerGrid`.
5. Hook up wallet balance updates when transactions are saved or deleted.
6. Add preview fixtures for wallets/transactions to `PersistenceController.preview`.
7. Smoke-test onboarding -> add wallet -> add transaction flows.

## 7. Risks & Mitigations
- **State explosion**: Use dedicated view models per screen to keep `AppSettingsStore` lean.
- **Exchange rate dependency**: when service unavailable, store manual conversion rate with transaction to keep history consistent.
- **Data migrations**: this is the first major model bump; record the version for future migrations and consider lightweight migrations.
- **Keyboard-heavy forms**: implement custom keypad later; for Phase 2 we use system keypad with formatting helper to unblock testing.

## 8. Out-of-Scope for Phase 2
- Budgets/Goals integration (Phase 4).
- Investment syncing (Phase 3).
- CloudKit sync toggle hooking into real CK container.
