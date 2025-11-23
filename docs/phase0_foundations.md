# Ledgerly Phase 0 – Foundations

## 1. Storage & Architecture Baseline
- **Persistence stack**: stay on Core Data (already scaffolded) with SwiftData-compatible models in mind. Core Data brings CloudKit sync support, battle-tested migrations, background contexts, and works on iOS 15+ so we avoid limiting devices.
- **Layering**: expose repositories powered by `NSPersistentContainer` + Combine publishers, and keep SwiftUI views unaware of Core Data specifics.
- **Offline-first**: every remote dependency writes to Core Data caches (`PriceSnapshot`, `ExchangeRateSnapshot`, etc.) so screens read synchronously from disk.
- **Sync toggle**: wrap CloudKit enablement in `AppSettings` so the user can keep all data local by default.

## 2. Primary Data Models
(All entity names are Core Data models with generated Swift structs/actors.)

### 2.1 Configuration & Exchange Profiles
- `AppSettings`: singleton row holding `baseCurrencyCode`, `exchangeMode` (official / parallel / manual), `priceRefreshIntervalMinutes`, `cloudSyncEnabled`, and default notification flags.
- `ExchangeRateProfile`: user-defined rate sets with `profileType` (official feed / parallel feed / manual), `primarySource` (API identifier), `lastUpdated`, `notes`.
- `ExchangeRate`: scoped to a profile and currency pair. Fields: `fromCode`, `toCode`, `rate`, `inverseRate`, `source`, `timestamp`, `confidence` (manual vs fetched), `isCustomOverride`.

### 2.2 Wallets, Categories, Tags
- `Wallet`: `id`, `name`, `iconName`, `baseCurrencyCode`, `type` (salary, cash, bank, freelance, custom), `startingBalance`, `currentBalance`, `institution`, `sortOrder`, `includeInNetWorth` (bool), `archived`.
- `Category`: `id`, `name`, `type` (expense/income), `iconName`, `colorHex`, `parentCategory`, `budgetingEnabled`, `sortOrder`.
- `Tag`: lightweight label for ad-hoc grouping; used via many-to-many with transactions.

### 2.3 Transactions & Recurrence
- `Transaction`: unified entity with `direction` (expense or income), `wallet`, `amount`, `currencyCode`, `convertedAmountBase`, `category`, `notes`, `date`, `attachmentURL`, `exchangeProfileUsed`, `exchangeRateSnapshot`, `isTransfer`, `counterpartyWallet` (for transfers), `createdAt`, `updatedAt`.
- `TransactionSplit`: optional child entity storing `subAmount`, `subCategory`, `memo` for envelope-style budgeting.
- `RecurringMetadata`: attached to a “template” transaction, storing `frequency`, `startDate`, `endDate`, `nextRunDate`, `autoPost` (bool), `reminderID`.

### 2.4 Investments
- `InvestmentAccount`: similar to wallet but investment-specific (broker, accountType, baseCurrencyCode).
- `InvestmentAsset`: `symbol`, `assetType` (stock/ETF/crypto), `name`, `exchange`, `baseCurrencyCode`, `holdings` relationship.
- `HoldingLot`: `quantity`, `costPerUnit`, `fee`, `acquiredDate`, `walletOrigin` (optional), `notes`.
- `PriceSnapshot`: `asset`, `price`, `currencyCode`, `source`, `timestamp`, `confidence`, `isStale`.
- `AssetAllocationTarget`: optional percentages for categories (core vs speculative) powering Core/Tangible net worth calculations.

### 2.5 Budgets & Goals
- `MonthlyBudget`: `month`, `year`, `category`, `limitAmount`, `currencyCode`, `alert50`, `alert80`, `alert100`, `autoReset`, `carriedOverAmount`.
- `BudgetAlert`: log entity capturing each threshold notification to avoid duplicates and support audit.
- `SavingGoal`: `name`, `targetAmount`, `currencyCode`, `deadline`, `linkedWallet`, `linkedCategory`, `currentAmount`, `autoFundRule`, `status`.

### 2.6 Net Worth & Manual Entries
- `ManualAsset`: `name`, `type` (tangible/intangible), `value`, `currencyCode`, `valuationDate`, `volatility` flag, `notes`, `includeInCore`, `includeInTangible`.
- `ManualLiability`: `name`, `type`, `balance`, `currencyCode`, `interestRate`, `dueDate`.
- `NetWorthSnapshot`: month-bound record with aggregated totals: `totalAssets`, `totalLiabilities`, `coreNetWorth`, `tangibleNetWorth`, `volatileAssetValue`, `timestamp`, plus JSON blob for breakdown used in charts.

### 2.7 Audit & Sync Support
- `ChangeLog`: generic entity capturing CRUD actions and entity IDs for future conflict resolution or debugging CloudKit sync issues.

## 3. Exchange-Rate Engine Blueprint
1. **Source hierarchy**: App sets a global `baseCurrencyCode`. Each wallet chooses its own currency; conversions always go `walletCurrency -> baseCurrency -> presentation currency` using the active `ExchangeRateProfile`.
2. **Modes**:
   - Official: rates fetched from a trusted API and cached as `ExchangeRate` rows tagged `profileType=official`.
   - Parallel: second API/feed; fallback to manual entry if API unavailable.
   - Manual: user enters per-pair rates; flagged as `confidence=manual` and exempt from automatic refresh.
3. **Snapshots on use**: every transaction/investment stores the exact `exchangeRateSnapshot` used (pair, rate, timestamp) for reproducible history.
4. **Staleness handling**: when a rate exceeds configured `maxAgeMinutes`, UI surfaces a warning and conversions use last-known value until refreshed.
5. **Batch refresh**: background task fetches needed pairs (wallet currencies, holdings currencies) and writes them transactionally so views update atomically via Combine.
6. **Custom overrides**: per-transaction override allowed, writing a one-off `ExchangeRateSnapshot` row that does not mutate the shared `ExchangeRate` entity.

## 4. Market Data & Offline Strategy

### 4.1 Provider Evaluation
| Provider | Coverage | Free-tier Rate Limit | Pros | Cons | Decision |
| --- | --- | --- | --- | --- | --- |
| CoinGecko | Crypto only | 10-50 calls/min (IP limited) | No API key, solid coin list, pricing in 30+ currencies | No equities, rate limit tied to IP | Use for crypto holdings |
| Alpha Vantage | Stocks, ETFs, FX, Crypto (basic) | 25 requests/day free; paid tiers affordable | Simple JSON, FX endpoints for official rates, approved for hobby apps | Very low daily quota, throttles on bursts | Use for FX + US equities via paid micro tier (~$50/yr) |
| Finnhub | Global equities, crypto, forex | 60 API calls/min | Rich data (fundamentals, news), websocket option | Requires API key, free tier attribution, TLS only | Consider for later premium tier; not MVP |
| Open Exchange Rates (optional) | 170+ currencies | 1k calls/month | Reliable FX baseline | Paid for parallel rates? not available | Use only if Alpha Vantage insufficient |

**MVP mix**: Alpha Vantage (official FX + major equities) + CoinGecko (crypto). Leave Finnhub integration behind feature flag for future premium tier.

### 4.2 Rate-Limit & Caching Plan
- **Price fetch scheduler**: background task runs every 30 minutes when on Wi-Fi + power, and on manual pull-to-refresh. Scheduler deduplicates symbols/pairs needed by checking holdings + watchlist.
- **Local cache**: each response yields `PriceSnapshot` rows keyed by `(asset, provider)`. Keep at least 72 hours of history for sparkline charts; purge older rows nightly.
- **TTL policy**:
  - Crypto: warn after 15 minutes stale; equities/FX: warn after 60 minutes. UI shows badge "Last updated X mins ago".
  - If TTL expired and network unavailable, continue using last snapshot but highlight "stale" state.
- **Batching**: group up to 5 symbols per Alpha Vantage call (supports `batch_stock_quotes` / `fx_batch`); fallback to sequential requests respecting 1s delay to avoid ban.
- **Parallel rates**: allow user to input manual parallel-market rate profiles stored locally; optionally scrape from a CSV/JSON dropped in Files app since API supply is scarce.
- **Error handling**: exponential backoff recorded in `ChangeLog`, and UI surfaces friendly message rather than blocking navigation.
- **Privacy**: never upload holdings to third-party; only send the symbol list required, and obfuscate by trimming wallet names before network boundary.
