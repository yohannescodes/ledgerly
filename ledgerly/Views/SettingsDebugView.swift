import SwiftUI
import Combine
import UniformTypeIdentifiers

struct SettingsDebugView: View {
    @EnvironmentObject private var appSettingsStore: AppSettingsStore
    @EnvironmentObject private var netWorthStore: NetWorthStore
    @EnvironmentObject private var walletsStore: WalletsStore
    @EnvironmentObject private var budgetsStore: BudgetsStore
    @EnvironmentObject private var goalsStore: GoalsStore
    @EnvironmentObject private var investmentsStore: InvestmentsStore

    private let backupService: DataBackupService

    @State private var exportedFile: ExportedFile?
    @State private var showingImporter = false
    @State private var alertMessage: String?
    @State private var showingRatePicker = false
    @State private var pendingRateCode: String? = nil
    @State private var pendingRateValue: Decimal = 1
    @State private var isEditingRate = false

    init(persistence: PersistenceController = PersistenceController.shared) {
        self.backupService = DataBackupService(persistence: persistence)
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

    private var cloudSyncBinding: Binding<Bool> {
        Binding(
            get: { appSettingsStore.snapshot.cloudSyncEnabled },
            set: { appSettingsStore.toggleCloudSync($0) }
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

                Toggle("iCloud Sync", isOn: cloudSyncBinding)
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

            Section("Exchange Rates") {
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

            Section("Backup & Restore") {
                Button(action: exportBackup) {
                    Label("Export Full Backup", systemImage: "externaldrive")
                }
                Button(action: { showingImporter = true }) {
                    Label("Import Backup", systemImage: "arrow.down.doc")
                }
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
        .alert("Data Management", isPresented: Binding(get: { alertMessage != nil }, set: { if !$0 { alertMessage = nil } })) {
            Button("OK", role: .cancel) { alertMessage = nil }
        } message: {
            Text(alertMessage ?? "")
        }
    }

    private func exportBackup() {
        do {
            let url = try backupService.exportBackup()
            exportedFile = ExportedFile(url: url)
        } catch {
            alertMessage = "Unable to build backup."
        }
    }

    private func handleImport(result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            do {
                try backupService.importBackup(from: url)
                refreshStoresAfterImport()
                alertMessage = "Backup imported successfully."
            } catch {
                alertMessage = "Failed to import backup."
            }
        case .failure(let error):
            if let cocoa = error as? CocoaError, cocoa.code == .userCancelled { return }
            alertMessage = "Could not read selected file."
        }
    }

    private func refreshStoresAfterImport() {
        walletsStore.reload()
        budgetsStore.reload()
        goalsStore.reload()
        investmentsStore.reload()
        netWorthStore.reload()
        appSettingsStore.refresh()
    }

    private var rateEntries: [(code: String, value: Decimal)] {
        appSettingsStore.snapshot.exchangeRates
            .sorted { $0.key < $1.key }
            .map { ($0.key, $0.value) }
    }

    private func presentRateEditor(code: String?, value: Decimal?) {
        pendingRateCode = code
        pendingRateValue = value ?? 1
        isEditingRate = (code != nil)
        showingRatePicker = true
    }

    private func formattedRate(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 6
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSDecimalNumber(decimal: value)) ?? "0"
    }
}

#Preview {
    SettingsDebugView(persistence: PersistenceController.preview)
        .environmentObject(AppSettingsStore(persistence: PersistenceController.preview))
        .environmentObject(NetWorthStore(persistence: PersistenceController.preview))
        .environmentObject(WalletsStore(persistence: PersistenceController.preview))
        .environmentObject(BudgetsStore(persistence: PersistenceController.preview))
        .environmentObject(GoalsStore(persistence: PersistenceController.preview))
        .environmentObject(InvestmentsStore(persistence: PersistenceController.preview))
}

private struct ExportedFile: Identifiable {
    let id = UUID()
    let url: URL
}
