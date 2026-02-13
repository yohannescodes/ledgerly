import CoreData
import SwiftUI
import UniformTypeIdentifiers

struct SettingsDebugView: View {
    @EnvironmentObject private var appSettingsStore: AppSettingsStore
    @EnvironmentObject private var netWorthStore: NetWorthStore
    @EnvironmentObject private var walletsStore: WalletsStore
    @EnvironmentObject private var budgetsStore: BudgetsStore
    @EnvironmentObject private var goalsStore: GoalsStore

    private let persistence: PersistenceController
    private let backupService: DataBackupService
    private let exportService: DataExportService

    @State private var exportedFile: ExportedFile?
    @State private var showingImporter = false
    @State private var alertMessage: String?
    @State private var showingRatePicker = false
    @State private var pendingRateCode: String? = nil
    @State private var pendingRateValue: Decimal = 1
    @State private var isEditingRate = false
    @State private var showingNetWorthRebuild = false
    @State private var exchangeRateAPIKeyInput = ""
    @State private var isSyncingOfficialRates = false
    @State private var stockApiKeyInput = ""
    @State private var cryptoApiKeyInput = ""

    init(persistence: PersistenceController = PersistenceController.shared) {
        self.persistence = persistence
        self.backupService = DataBackupService(persistence: persistence)
        self.exportService = DataExportService(persistence: persistence)
    }

    private var baseCurrencyBinding: Binding<String> {
        Binding(
            get: { appSettingsStore.snapshot.baseCurrencyCode },
            set: { appSettingsStore.updateBaseCurrency(code: $0) }
        )
    }

    private var exchangeModeBinding: Binding<ExchangeMode> {
        Binding(
            get: { appSettingsStore.snapshot.exchangeMode },
            set: { appSettingsStore.updateExchangeMode($0) }
        )
    }

    var body: some View {
        Form {
            Section(header: Text("Profile"), footer: Text("Future versions will let you edit onboarding settings here.")) {
                Picker("Base Currency", selection: baseCurrencyBinding) {
                    ForEach(CurrencyDataSource.all, id: \.code) { option in
                        Text("\(option.name) (\(option.code))")
                            .tag(option.code)
                    }
                }

                Picker("Exchange Mode", selection: exchangeModeBinding) {
                    ForEach(ExchangeMode.allCases, id: \.self) { mode in
                        Text(mode.title)
                            .tag(mode)
                    }
                }

                Toggle("Notifications", isOn: Binding(
                    get: { appSettingsStore.snapshot.notificationsEnabled },
                    set: { appSettingsStore.updateNotifications($0) }
                ))
                Text("Onboarding Completed: \(appSettingsStore.snapshot.hasCompletedOnboarding ? "Yes" : "No")")
                    .foregroundStyle(.secondary)
            }

            Section("Dashboard") {
                NavigationLink {
                    DashboardPreferencesView()
                } label: {
                    Label("Customize Home Widgets", systemImage: "rectangle.on.rectangle.angled")
                }
            }

            Section("Categories") {
                NavigationLink {
                    CategoryManagementView()
                } label: {
                    Label("Manage Transaction Categories", systemImage: "tag")
                }
            }

            Section("Exchange Rates") {
                if appSettingsStore.snapshot.exchangeMode == .official {
                    SecureField("ExchangeRate-API Key", text: $exchangeRateAPIKeyInput)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .privacySensitive()

                    Button(action: saveAndSyncOfficialRates) {
                        if isSyncingOfficialRates {
                            HStack(spacing: 8) {
                                ProgressView()
                                Text("Syncing Official Rates...")
                            }
                        } else {
                            Text("Save Key & Sync Official Rates")
                        }
                    }
                    .disabled(isSyncingOfficialRates || !hasUnsavedExchangeRateAPIKeyChanges)

                    Button(action: refreshOfficialRates) {
                        Text("Refresh Official Rates")
                    }
                    .disabled(isSyncingOfficialRates || !hasStoredExchangeRateAPIKey)

                    if hasStoredExchangeRateAPIKey {
                        Button(role: .destructive, action: clearExchangeRateAPIKey) {
                            Text("Remove ExchangeRate-API Key")
                        }
                    }

                    if rateEntries.isEmpty {
                        Text("No official rates synced yet. Save your key to fetch rates.")
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Using \(rateEntries.count) synced official rates for base \(appSettingsStore.snapshot.baseCurrencyCode).")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    if rateEntries.isEmpty {
                        Text("Add conversion rates to normalize multi-currency wallets.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(rateEntries, id: \.code) { entry in
                        Button {
                            presentRateEditor(code: entry.code, value: entry.value)
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(entry.code)
                                    Text("1 \(entry.code) = \(formattedRate(entry.value)) \(appSettingsStore.snapshot.baseCurrencyCode)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(Color.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    Button(action: { presentRateEditor(code: nil, value: nil) }) {
                        Label("Add Currency Rate", systemImage: "plus")
                    }
                }
            }

            Section(
                header: Text("Market Data API Keys"),
                footer: Text("Optional: add your own keys for real-time stock and crypto valuation. Stock quotes use Alpha Vantage and crypto quotes use CoinGecko.")
            ) {
                SecureField("Alpha Vantage API Key (Stocks)", text: $stockApiKeyInput)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .privacySensitive()

                SecureField("CoinGecko API Key (Crypto)", text: $cryptoApiKeyInput)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .privacySensitive()

                Button("Save API Keys", action: saveMarketDataAPIKeys)
                    .disabled(!hasUnsavedMarketDataKeyChanges)

                if hasStoredMarketDataKey {
                    Button(role: .destructive, action: clearMarketDataAPIKeys) {
                        Text("Remove Saved API Keys")
                    }
                }
            }

            Section("Backup & Restore") {
                Button(action: exportBackup) {
                    Label("Export Full Backup", systemImage: "externaldrive")
                }
                Button(action: { showingImporter = true }) {
                    Label("Import Backup", systemImage: "arrow.down.doc")
                }
            }

            Section("Export CSV") {
                ForEach(CSVExportKind.allCases) { kind in
                    Button(action: { exportCSV(kind: kind) }) {
                        Label("Export \(kind.title) CSV", systemImage: "doc.plaintext")
                    }
                }
            }

            Section("Net Worth History") {
                Button(role: .destructive) {
                    showingNetWorthRebuild = true
                } label: {
                    Label("Rebuild Net Worth Snapshots", systemImage: "arrow.clockwise")
                }
                Text("Deletes existing snapshots for the currently selected exchange mode and rebuilds daily totals (5 PM local time) starting from today using transactions and manual assets. Uses current FX rates and valuations, so past days are approximate.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.json]) { result in
            handleImport(result: result)
        }
        .sheet(isPresented: $showingRatePicker) {
            ExchangeRateFormView(
                baseCurrency: appSettingsStore.snapshot.baseCurrencyCode,
                selectedCurrency: pendingRateCode,
                rateValue: pendingRateValue,
                onSave: { code, value in
                    appSettingsStore.updateExchangeRate(code: code, value: value)
                    showingRatePicker = false
                },
                onDelete: isEditingRate ? {
                    if let code = pendingRateCode {
                        appSettingsStore.removeExchangeRate(code: code)
                    }
                    showingRatePicker = false
                } : nil
            )
        }
        .sheet(item: $exportedFile) { payload in
            ShareSheet(activityItems: [payload.url])
        }
        .alert("Rebuild Net Worth History?", isPresented: $showingNetWorthRebuild) {
            Button("Rebuild", role: .destructive, action: rebuildNetWorthHistory)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will delete net worth snapshots for the currently selected exchange mode and recreate daily totals from today. This cannot be undone.")
        }
        .alert("Data Management", isPresented: Binding(get: { alertMessage != nil }, set: { if !$0 { alertMessage = nil } })) {
            Button("OK", role: .cancel) { alertMessage = nil }
        } message: {
            Text(alertMessage ?? "")
        }
        .onAppear(perform: syncAPIKeyInputs)
    }

    private func exportBackup() {
        do {
            let url = try backupService.exportBackup()
            exportedFile = ExportedFile(url: url)
        } catch {
            alertMessage = "Unable to build backup."
        }
    }

    private func exportCSV(kind: CSVExportKind) {
        do {
            let url = try exportService.export(kind: kind)
            exportedFile = ExportedFile(url: url)
        } catch {
            alertMessage = "Unable to export \(kind.title.lowercased()) CSV."
        }
    }

    private func handleImport(result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            do {
                try backupService.importBackup(from: url)
                refreshStoresAfterImport()
                NotificationCenter.default.post(name: .transactionsDidChange, object: nil)
                alertMessage = "Backup imported successfully."
            } catch {
                alertMessage = error.localizedDescription
            }
        case .failure(let error):
            if let cocoa = error as? CocoaError, cocoa.code == .userCancelled { return }
            alertMessage = "Could not read selected file."
        }
    }

    private func refreshStoresAfterImport() {
        let context = persistence.container.viewContext
        context.performAndWait {
            context.refreshAllObjects()
        }
        walletsStore.reload()
        budgetsStore.reload()
        goalsStore.reload()
        netWorthStore.reload()
        appSettingsStore.refresh()
    }

    private var rateEntries: [(code: String, value: Decimal)] {
        appSettingsStore.snapshot.exchangeRates
            .sorted { $0.key < $1.key }
            .map { ($0.key, $0.value) }
    }

    private var hasStoredExchangeRateAPIKey: Bool {
        appSettingsStore.snapshot.exchangeRateAPIKey != nil
    }

    private var hasUnsavedExchangeRateAPIKeyChanges: Bool {
        normalizedApiKey(exchangeRateAPIKeyInput) != appSettingsStore.snapshot.exchangeRateAPIKey
    }

    private var hasStoredMarketDataKey: Bool {
        appSettingsStore.snapshot.stockApiKey != nil || appSettingsStore.snapshot.cryptoApiKey != nil
    }

    private var hasUnsavedMarketDataKeyChanges: Bool {
        normalizedApiKey(stockApiKeyInput) != appSettingsStore.snapshot.stockApiKey
            || normalizedApiKey(cryptoApiKeyInput) != appSettingsStore.snapshot.cryptoApiKey
    }

    private func presentRateEditor(code: String?, value: Decimal?) {
        pendingRateCode = code
        pendingRateValue = value ?? 1
        isEditingRate = (code != nil)
        showingRatePicker = true
    }

    private func rebuildNetWorthHistory() {
        netWorthStore.rebuildDailySnapshots { result in
            switch result {
            case .success(let count):
                let mode = appSettingsStore.snapshot.exchangeMode.title
                alertMessage = "Rebuilt \(count) daily snapshots for \(mode) mode."
            case .failure:
                alertMessage = "Failed to rebuild net worth snapshots."
            }
        }
    }

    private func saveMarketDataAPIKeys() {
        stockApiKeyInput = normalizedApiKey(stockApiKeyInput) ?? ""
        cryptoApiKeyInput = normalizedApiKey(cryptoApiKeyInput) ?? ""
        appSettingsStore.updateMarketDataAPIKeys(stock: stockApiKeyInput, crypto: cryptoApiKeyInput)
        alertMessage = "Market data API keys updated."
    }

    private func clearMarketDataAPIKeys() {
        stockApiKeyInput = ""
        cryptoApiKeyInput = ""
        appSettingsStore.clearMarketDataAPIKeys()
        alertMessage = "Market data API keys removed."
    }

    private func syncAPIKeyInputs() {
        exchangeRateAPIKeyInput = appSettingsStore.snapshot.exchangeRateAPIKey ?? ""
        stockApiKeyInput = appSettingsStore.snapshot.stockApiKey ?? ""
        cryptoApiKeyInput = appSettingsStore.snapshot.cryptoApiKey ?? ""
    }

    private func saveAndSyncOfficialRates() {
        Task { @MainActor in
            await syncOfficialRates(usingInputKey: true)
        }
    }

    private func refreshOfficialRates() {
        Task { @MainActor in
            await syncOfficialRates(usingInputKey: false)
        }
    }

    private func clearExchangeRateAPIKey() {
        exchangeRateAPIKeyInput = ""
        appSettingsStore.clearExchangeRateAPIKey()
        alertMessage = "ExchangeRate-API key removed."
    }

    @MainActor
    private func syncOfficialRates(usingInputKey: Bool) async {
        let keyOverride = usingInputKey ? normalizedApiKey(exchangeRateAPIKeyInput) : nil
        if usingInputKey, keyOverride == nil {
            appSettingsStore.clearExchangeRateAPIKey()
            alertMessage = "ExchangeRate-API key removed."
            return
        }

        isSyncingOfficialRates = true
        defer { isSyncingOfficialRates = false }

        do {
            let result = try await appSettingsStore.syncOfficialExchangeRates(apiKeyOverride: keyOverride)
            exchangeRateAPIKeyInput = appSettingsStore.snapshot.exchangeRateAPIKey ?? keyOverride ?? ""
            alertMessage = "Synced \(result.ratesCount) official rates for \(result.baseCurrencyCode)."
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    private func formattedRate(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 6
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSDecimalNumber(decimal: value)) ?? "0"
    }

    private func normalizedApiKey(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

#Preview {
    SettingsDebugView(persistence: PersistenceController.preview)
        .environmentObject(AppSettingsStore(persistence: PersistenceController.preview))
        .environmentObject(NetWorthStore(persistence: PersistenceController.preview))
        .environmentObject(WalletsStore(persistence: PersistenceController.preview))
        .environmentObject(BudgetsStore(persistence: PersistenceController.preview))
        .environmentObject(GoalsStore(persistence: PersistenceController.preview))
}

private struct ExportedFile: Identifiable {
    let id = UUID()
    let url: URL
}
