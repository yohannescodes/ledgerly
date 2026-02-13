//
//  ContentView.swift
//  ledgerly
//
//  Created by Yohannes Haile on 11/21/25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var appSettingsStore: AppSettingsStore
    @EnvironmentObject private var transactionsStore: TransactionsStore

    var body: some View {
        Group {
            if appSettingsStore.snapshot.hasCompletedOnboarding {
                MainTabView(transactionsStore: transactionsStore)
            } else {
                OnboardingView(initialSnapshot: appSettingsStore.snapshot)
            }
        }
        .animation(.easeInOut, value: appSettingsStore.snapshot.hasCompletedOnboarding)
        .task(id: officialRateSyncTrigger) {
            await syncOfficialRatesIfNeeded()
        }
    }

    private var officialRateSyncTrigger: String {
        let snapshot = appSettingsStore.snapshot
        return [
            snapshot.exchangeMode.rawValue,
            snapshot.baseCurrencyCode.uppercased(),
            snapshot.exchangeRateAPIKey ?? ""
        ].joined(separator: "|")
    }

    @MainActor
    private func syncOfficialRatesIfNeeded() async {
        let snapshot = appSettingsStore.snapshot
        guard snapshot.exchangeMode == .official else { return }
        guard snapshot.exchangeRateAPIKey != nil else { return }
        _ = try? await appSettingsStore.syncOfficialExchangeRates()
    }
}

#Preview {
    ContentView()
        .environmentObject(AppSettingsStore(persistence: PersistenceController.preview))
        .environmentObject(TransactionsStore(persistence: PersistenceController.preview))
        .environmentObject(BudgetsStore(persistence: PersistenceController.preview))
        .environmentObject(GoalsStore(persistence: PersistenceController.preview))
}
