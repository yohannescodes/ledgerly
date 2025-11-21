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

    init() {
        let persistence = PersistenceController.shared
        self.persistenceController = persistence
        _appSettingsStore = StateObject(wrappedValue: AppSettingsStore(persistence: persistence))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(appSettingsStore)
        }
    }
}
