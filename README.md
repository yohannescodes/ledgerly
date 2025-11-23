# Ledgerly Ledgerly is a SwiftUI + Core Data personal finance app that keeps 
every data point on-device. It helps you track wallets, transactions, budgets, 
goals, manual assets/liabilities, investments, and your overall financial health
 with live currency conversions and analytics. ## Table of Contents 1. 
[Architecture](#architecture) 2. [Feature Tour](#feature-tour) 3. [Currency & 
Exchange Rates](#currency--exchange-rates) 4. [Running the App](#running-the-
app) 5. [Data Model Overview](#data-model-overview) 6. [Extending the 
App](#extending-the-app) 7. [Screenshots](#screenshots) --- ## Architecture - 
**SwiftUI-first UI** with tab-based navigation (`MainTabView`), dedicated views 
per module, and sheet-driven flows for create/edit actions. - **Core Data** 
persistence managed by PersistenceController` and domain-specific stores 
(`WalletsStore`, `TransactionsStore`, etc.) - **Combine bindings** to propagate 
changes: stores publish through `@Published`, and the Net Worth dashboard 
listens via notifications (wallets/investments) to remain real time. - 
**Currency conversion** is centralized in `CurrencyConverter`, using base 
currency + custom rates defined in Settings. - **ManualInvestmentPriceService** 
pulls CoinGecko quotes to refresh manual holdings (and falls back to s,his month, last month, income, expenses). - Sectioned list 
grouped by date. - Advanced filters (segment, wallet, date range, search) with a
 dedicated sheet. - Detailed transaction view with delete action. - Add 
transactions with a form supporting expenses/income/transfers, wallet selection,
 currency picker, categories, and notes. ### Budgets & Goals - Budgets tab shows
 monthly category spend vs. limits (alerts integrate with the notifications 
store). - Goals tab lists savings goals with progress bars and deadlines. ### 
Manual Entries - Assets, receivables, liabilities, and investments can be logged
 with custom currencies and delete/edit flows. - Investments capture purchase 
units + cost per unit and sync live CoinGecko prices to surface profit/loss. - 
Receivables automatically fe and 
liabilities contribute to your total net worth. - **Expense Breakdown** card: 
pie chart of recent expenses by category so you can spot heavy spenders 
instantly. - **Income Progress** card: last 12 months of income visualized in a 
bar chart. - **Budgets & Goals preview** cards keep spending limits and savings 
progress front and center. - Links to manage manual assets, receivables, and 
liabilities. ### Wallets - Create income/checking/savings/crypto/etc. wallets, 
each with its own currency and icon. - Balances update instantly after 
transactions, transfers, or investment funding/withdrawals. - Swipe to delete 
wallets, open forms to edit, and track manual receivables/liabilities in the 
shared manual entries screen. ### Transactions - Fully featured ledger: - 
Summary tiles (t
deterministic local pricing when offline). ## Feature Tour ### Onboarding - 
Guides users through choosing a base currency, exchange-rate mode 
(official/parallel/manual), and summary confirmation. ### Home - **Net Worth 
Breakdown** card: highlights how assets, investments, wallets, receivable
