import SwiftUI

struct SettingsDebugView: View {
    @EnvironmentObject private var appSettingsStore: AppSettingsStore

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
        }
    }
}

#Preview {
    SettingsDebugView()
        .environmentObject(AppSettingsStore(persistence: PersistenceController.preview))
}
