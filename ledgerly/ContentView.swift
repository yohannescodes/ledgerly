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
    }
}

#Preview {
    ContentView()
        .environmentObject(AppSettingsStore(persistence: PersistenceController.preview))
}
