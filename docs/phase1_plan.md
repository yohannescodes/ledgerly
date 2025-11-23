# Ledgerly Phase 1 – Settings, Onboarding & Persistence Layer

## 1. Objectives
1. Introduce a settings/onboarding experience that captures the base currency, preferred exchange-rate mode, and optional CloudKit sync toggle before the user lands on Home.
2. Establish the production persistence stack (Core Data) with repositories/actors and background context helpers so future phases can plug into a consistent API.
3. Deliver AppSettings storage + defaults, along with dependency injection wiring for SwiftUI views.

## 2. AppSettings & Onboarding Blueprint
- **AppSettings entity** (as defined in Phase 0) will be created with a deterministic `objectID` so we can fetch/update without fetch requests.
- **Defaults loader**: at first launch, populate base currency from `Locale.current.currency?.identifier ?? "USD"`, exchange mode = `official`, and disable CloudKit sync.
- **Onboarding flow**:
  1. Launch screen checks `AppSettings.hasCompletedOnboarding`. If false, present a full-screen `OnboardingContainer` instead of the main tabs.
  2. Step 1 – Welcome + privacy promise, CTA to "Get Started".
  3. Step 2 – Base currency picker using `Locale.currencyCodes` or static ISO list with search; preview conversions for clarity.
  4. Step 3 – Exchange mode explanation cards (Official, Parallel, Manual) with description + recommended use cases. Selection saves to settings.
  5. Step 4 – Optional Cloud Sync toggle (local only vs iCloud) with benefits/caveats text.
  6. Step 5 – Confirmation summary and `Finish` button that sets `hasCompletedOnboarding = true` and routes to Home.
- **Re-entry**: Settings tab will expose the same options for editing later; onboarding only guarantees initial values.

## 3. Persistence & Repository Architecture
- **CoreDataStack**: wrap `NSPersistentContainer` setup into a new `PersistenceController` variant that exposes:
  - `viewContext` (main queue, `automaticallyMergesChangesFromParent = true`).
  - `backgroundContext()` factory that configures `mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy` and writes via perform blocks.
  - `seedIfNeeded()` method that ensures `AppSettings` row exists.
- **Repositories** (protocol + implementation pattern using Swift actors when sync needed):
  - `AppSettingsRepository`: CRUD + publisher bridging to Combine via `@Published` state inside an actor; caches the singleton object to avoid repeated fetches.
  - `WalletRepository`, `CategoryRepository`, etc., stubbed but not implemented yet—only define protocols so later features wire against them.
- **Dependency Injection**: create `EnvironmentValues` extensions (e.g., `EnvironmentKey` for settings repository) or use `@StateObject` view models to pass the repository graph. For Phase 1, inject `AppSettingsViewModel` into onboarding and settings screens.
- **Preview data**: extend `PersistenceController.preview` to seed sample `AppSettings`/wallets for SwiftUI previews.

## 4. UI Stack Adjustments
- Replace the default `NavigationView` list with a composable root that conditionally shows `OnboardingContainer` or the `MainTabView` (placeholder for now).
- `OnboardingContainer` stores transient state (`selectedCurrency`, `selectedExchangeMode`, `cloudSyncEnabled`) and persists via the repository when finishing. Each step is a `TabView` or pager with `Continue` disabled until a choice is made.
- Add a minimal `SettingsView` to the eventual tab bar that reads/writes `AppSettings` so QA can verify persistence quickly.

## 5. Implementation Tasks Checklist
1. Update Core Data model to include `AppSettings` entity with required attributes and a fetch-or-create helper method.
2. Refactor `PersistenceController` into its long-term shape (background contexts, seeding logic, preview data).
3. Build `AppSettingsRepository` (protocol + CoreData-backed implementation) and unit-testable methods (load, update base currency, update mode, toggle sync, mark onboarding complete).
4. Create onboarding SwiftUI flow with currency picker and exchange-mode selection components.
5. Swap `ContentView` root to an app shell that decides between onboarding vs placeholder tabs, and wire in the repository via environment/state.
6. Add temporary `SettingsDebugView` accessible from tabs to manually edit AppSettings while other tabs are stubbed.

## 6. Risks & Mitigations
- **Blocking launch if settings missing**: ensure onboarding can be dismissed/relaunched; store partial progress so quitting mid-flow doesn’t corrupt data.
- **Currency list UX**: static ISO list is long; include search + top suggestions (locale currency, USD, EUR) for quick selection.
- **Combine + Core Data sync**: to avoid threading crashes, route all writes through background contexts and publish updates on main actor.
- **CloudKit entitlements**: keep toggle hidden until the project adds entitlements so App Store validation isn’t blocked.
