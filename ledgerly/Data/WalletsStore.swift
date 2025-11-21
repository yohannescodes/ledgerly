import CoreData
import Foundation
import SwiftUI
import Combine

@MainActor
final class WalletsStore: ObservableObject {
    @Published private(set) var wallets: [WalletModel] = []

    private let persistence: PersistenceController

    init(persistence: PersistenceController) {
        self.persistence = persistence
        reload()
    }

    func reload() {
        let context = persistence.container.viewContext
        do {
            let results = try context.fetch(Wallet.fetchRequestAll())
            wallets = results.map(WalletModel.init)
        } catch {
            assertionFailure("Failed to fetch wallets: \(error)")
            wallets = []
        }
    }
}
