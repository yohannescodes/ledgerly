# Ledgerly Phase 3 – Investments & Net Worth

## 1. Objectives
1. Track investment accounts/holdings with real-time price snapshots and unrealized P/L per the PRD.
2. Compute Core/Tangible/Total Net Worth via manual assets/liabilities + wallet balances + investments with monthly snapshots.
3. Provide an Investments tab and Home dashboard widgets summarizing holdings and net-worth trajectory.

## 2. Scope Review
- **Investments**: stocks, ETFs, crypto with price feeds (Alpha Vantage + CoinGecko). Support multiple accounts (brokerage, exchange, wallet) with account-level base currency.
- **Holdings**: lots per asset (quantity, cost basis, acquisition date, fees) to calculate unrealized gains.
- **Price snapshots**: cached locally with staleness warnings and offline fallback.
- **Net worth**: Core, Tangible, Total definitions from PRD; manual assets/liabilities; monthly snapshot schedule.
- **UI**: Investments tab (list + detail) and Home card (net worth summary + sparkline).

## 3. Data Model Additions
- `InvestmentAccount`: `identifier`, `name`, `institution`, `accountType`, `currencyCode`, `includeInNetWorth`, `notes`, relationships to holdings.
- `InvestmentAsset`: `identifier`, `symbol`, `assetType` (stock/etf/crypto), `name`, `exchange`, `currencyCode`, `category` (core/speculative), relationships to holdings + snapshots.
- `HoldingLot`: `identifier`, `quantity`, `costPerUnit`, `fee`, `acquiredDate`, `notes`, `account`, `asset`.
- `PriceSnapshot`: `identifier`, `asset`, `price`, `currencyCode`, `provider`, `timestamp`, `isStale`.
- `ManualAsset` / `ManualLiability`: as defined in Phase 0.
- `NetWorthSnapshot`: `identifier`, `timestamp`, `totalAssets`, `totalLiabilities`, `coreNetWorth`, `tangibleNetWorth`, `volatileAssets`, `notes`. Optionally store JSON breakdown blob for charts.

Implementation steps: add entities + relationships to Core Data, create helper structs, seed preview data, and plan lightweight migrations.

## 4. Services & Repositories
- `InvestmentAccountsRepository`: CRUD, fetch accounts/holdings, compute account-level totals.
- `PriceService`: fetch prices from Alpha Vantage/CoinGecko, normalize to base currency, store snapshots, expose Combine publishers for UI updates.
- `NetWorthService`: gather wallet balances, holdings valuations, manual assets/liabilities, compute category totals, and write monthly snapshots.
- `NetWorthScheduler`: background task triggered monthly/every time user opens app to ensure snapshot exists.

## 5. UI Deliverables
1. **Investments Tab**
   - Accounts list with aggregated value and P/L.
   - Holdings detail screen with charts (sparkline from snapshots) and lot breakdown.
   - Pull-to-refresh invoking `PriceService`.
2. **Add Holding Flow**
   - Form to pick asset (search local list / manual entry), quantity, cost basis, fees, account, acquisition date.
   - Optional link to wallet for cash source.
3. **Home Dashboard Widgets**
   - Net worth summary card showing Total/Core/Tangible with delta vs last snapshot.
   - Mini-investments card highlighting top movers.
4. **Manual Assets/Liabilities Manager**
   - Table-style view for adding tangible/intangible assets and debts, included in net-worth calculations.

## 6. Implementation Checklist
1. Extend `.xcdatamodeld` with investment/net-worth entities; regenerate models.
2. Build repositories/helpers for investment accounts, assets, holdings, price snapshots, manual assets/liabilities, net-worth snapshots.
3. Implement `PriceService` (stub network calls to abide by restricted environment) with caching logic + Combine publisher.
4. Create Investments tab SwiftUI views and view models.
5. Add manual asset/liability editor and net-worth summary card on Home (wired to snapshots).
6. Write seed data for previews (demo accounts, holdings, snapshots).
7. Schedule net-worth snapshot creation (e.g., on app start if last snapshot >30 days old).

## 7. Risks & Mitigations
- **API rate limits**: queue symbol requests, dedupe holdings before hitting external APIs, honor TTL to avoid bans.
- **Offline valuation**: use last snapshot for valuations and show "stale" badges; allow manual price override per asset.
- **Data migrations**: large schema jump—enable lightweight migration and create new model version if needed.
- **Performance**: aggregated net-worth calculations should run off background contexts; consider caching computed totals per snapshot.

## 8. Out-of-Scope for Phase 3
- Budget integrations (Phase 4) and goal tracking.
- CloudKit sync & multi-device conflict resolution.
- Advanced analytics (sector allocation charts, etc.) beyond simple cards.
