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
    @EnvironmentObject private var investmentsStore: InvestmentsStore
    @EnvironmentObject private var budgetsStore: BudgetsStore
    @EnvironmentObject private var goalsStore: GoalsStore

    var body: some View {
        Group {
            if appSettingsStore.snapshot.hasCompletedOnboarding {
                MainTabView(
                    transactionsStore: transactionsStore,
                    investmentsStore: investmentsStore,
                    budgetsStore: budgetsStore,
                    goalsStore: goalsStore
                )
            } else {
                OnboardingView(initialSnapshot: appSettingsStore.snapshot)
            }
        }
        .animation(.easeInOut, value: appSettingsStore.snapshot.hasCompletedOnboarding)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppSettingsStore(persistence: PersistenceController.preview))
        .environmentObject(TransactionsStore(persistence: PersistenceController.preview))
        .environmentObject(InvestmentsStore(persistence: PersistenceController.preview))
        .environmentObject(BudgetsStore(persistence: PersistenceController.preview))
        .environmentObject(GoalsStore(persistence: PersistenceController.preview))
}
