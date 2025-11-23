//
//  ledgerlyApp.swift
//  ledgerly
//
//  Created by Yohannes Haile on 11/21/25.
//

import CoreData
import SwiftUI
import UserNotifications

@main
struct ledgerlyApp: App {
    let persistenceController: PersistenceController
    @StateObject private var appSettingsStore: AppSettingsStore
    @StateObject private var walletsStore: WalletsStore
    @StateObject private var transactionsStore: TransactionsStore
    @StateObject private var netWorthStore: NetWorthStore
    @StateObject private var budgetsStore: BudgetsStore
    @StateObject private var goalsStore: GoalsStore

    init() {
        let persistence = PersistenceController.shared
        self.persistenceController = persistence

        _appSettingsStore = StateObject(wrappedValue: AppSettingsStore(persistence: persistence))
        _walletsStore = StateObject(wrappedValue: WalletsStore(persistence: persistence))
        _transactionsStore = StateObject(wrappedValue: TransactionsStore(persistence: persistence))
        _netWorthStore = StateObject(wrappedValue: NetWorthStore(persistence: persistence))
        _budgetsStore = StateObject(wrappedValue: BudgetsStore(persistence: persistence))
        _goalsStore = StateObject(wrappedValue: GoalsStore(persistence: persistence))
        requestNotificationAuthorization()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(appSettingsStore)
                .environmentObject(walletsStore)
                .environmentObject(transactionsStore)
                .environmentObject(netWorthStore)
                .environmentObject(budgetsStore)
                .environmentObject(goalsStore)
        }
    }
}

private func requestNotificationAuthorization() {
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
}
