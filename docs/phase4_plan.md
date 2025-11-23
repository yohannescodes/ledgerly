# Ledgerly Phase 4 – Budgets & Goals

## 1. Objectives
1. Provide monthly category budgets with alerts at 50/80/100% thresholds.
2. Support savings goals (target amount + deadline) linked to wallets or categories.
3. Surface budgeting/goal progress in a dedicated tab and on the home dashboard.

## 2. Scope
- **Budgets**: monthly per-category limits with carry-over option, ability to enable/disable per category.
- **Alerts**: persistent log of threshold notifications to avoid spam and enable history.
- **Goals**: configurable name, target amount, savings destination (wallet/category), deadline, optional auto-fund rule.
- **UI**: Budgets tab (list, detail), goal creation flow, home widgets summarizing utilization + goal progress.

Out-of-scope: envelope budgeting, shared budgets, automated transfers beyond simple reminders.

## 3. Data Model Changes
- `MonthlyBudget`: `identifier`, `category`, `month`, `year`, `limitAmount`, `currencyCode`, `alert50Sent`, `alert80Sent`, `alert100Sent`, `carryOverAmount`, `autoReset` flag.
- `BudgetAlert`: `identifier`, `timestamp`, `category`, `threshold`, `spentAmount`, `month`, `year`.
- `SavingGoal`: `identifier`, `name`, `targetAmount`, `currencyCode`, `currentAmount`, `deadline`, `linkedWallet`, `linkedCategory`, `autoFundRule`, `status`.

Implementation steps:
1. Extend Core Data model with these entities/relationships.
2. Create helper models/repositories for budgets/goals.
3. Seed preview data (sample budgets/goals) for UI previews.

## 4. Services & Logic
- `BudgetService`: calculate actual spend per category (using transactions) and compare vs budgets; trigger alerts when crossing thresholds.
- `GoalsService`: compute progress, remaining amount/time, optionally prompt transfers.
- Notification scheduling (local notifications) for hitting thresholds/deadlines (phase 4.5).

## 5. UI Deliverables
1. Budgets Tab
   - List budgets with progress bars (spent vs limit).
   - Budget detail showing breakdown (transactions contributing, alert history).
   - Form to create/edit monthly budget (choose category, limit, carry-over, auto-reset).
2. Goals Tab / Section
   - Grid/list of goals with percent complete, due date.
   - Goal detail view and creation wizard (target, funding source, optional reminder).
3. Home Dashboard Widgets
   - Budget summary (e.g., “70% of Food budget used”).
   - Goal reminder card for the most urgent goal.

## 6. Implementation Checklist
1. Data model + helpers for budgets, alerts, goals.
2. Budget repository/service (fetch budgets, compute utilization, log alerts).
3. Goals repository/service (progress calculations, status updates).
4. Budgets tab UI (list, detail, creation form).
5. Goals UI (list, detail, creation form).
6. Home dashboard updates (budget summary + goal reminder).
7. Seed preview data.

## 7. Risks & Mitigations
- **Complex spend calculations**: cache monthly spend per category to avoid heavy queries; recompute on transaction changes.
- **Alert spam**: track alert log and throttle notifications.
- **Currency mismatches**: budgets/goals may use different currencies; convert using global base via exchange engine.

## 8. Out-of-Scope
- Shared budgets/goals across users.
- Automated bank transfers or recurring contributions (only reminders).
- Calendar integration beyond basic dates.
