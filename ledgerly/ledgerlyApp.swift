//
//  ledgerlyApp.swift
//  ledgerly
//
//  Created by Yohannes Haile on 11/21/25.
//

import CoreData
import SwiftUI
import Combine

@main
struct ledgerlyApp: App {
    let persistenceController: PersistenceController
    @StateObject private var appSettingsStore: AppSettingsStore
    @StateObject private var walletsStore: WalletsStore
    @StateObject private var transactionsStore: TransactionsStore
    @StateObject private var investmentsStore: InvestmentsStore
    @StateObject private var netWorthStore: NetWorthStore

    init() {
        let persistence = PersistenceController.shared
        self.persistenceController = persistence

        let alphaKey = ProcessInfo.processInfo.environment["ALPHAVANTAGE_API_KEY"]
        let alphaClient = alphaKey.map { AlphaVantageClient(apiKey: $0) }
        let coinClient = CoinGeckoClient()
        let priceService = PriceService(persistence: persistence, alphaClient: alphaClient, coinClient: coinClient)

        _appSettingsStore = StateObject(wrappedValue: AppSettingsStore(persistence: persistence))
        _walletsStore = StateObject(wrappedValue: WalletsStore(persistence: persistence))
        _transactionsStore = StateObject(wrappedValue: TransactionsStore(persistence: persistence))
        _investmentsStore = StateObject(wrappedValue: InvestmentsStore(persistence: persistence, priceService: priceService))
        _netWorthStore = StateObject(wrappedValue: NetWorthStore(persistence: persistence))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(appSettingsStore)
                .environmentObject(walletsStore)
                .environmentObject(transactionsStore)
                .environmentObject(investmentsStore)
                .environmentObject(netWorthStore)
        }
    }
}
