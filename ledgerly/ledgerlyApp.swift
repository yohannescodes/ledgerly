//
//  ledgerlyApp.swift
//  ledgerly
//
//  Created by Yohannes Haile on 11/21/25.
//

import CoreData
import SwiftUI

@main
struct ledgerlyApp: App {
    let persistenceController: PersistenceController
    @StateObject private var appSettingsStore: AppSettingsStore
    @StateObject private var walletsStore: WalletsStore
    @StateObject private var transactionsStore: TransactionsStore

    init() {
        let persistence = PersistenceController.shared
        self.persistenceController = persistence
        _appSettingsStore = StateObject(wrappedValue: AppSettingsStore(persistence: persistence))
        _walletsStore = StateObject(wrappedValue: WalletsStore(persistence: persistence))
        _transactionsStore = StateObject(wrappedValue: TransactionsStore(persistence: persistence))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(appSettingsStore)
                .environmentObject(walletsStore)
                .environmentObject(transactionsStore)
        }
    }
}
