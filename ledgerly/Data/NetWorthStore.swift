import CoreData
import Foundation
import SwiftUI
import Combine

@MainActor
final class NetWorthStore: ObservableObject {
    @Published private(set) var latestSnapshot: NetWorthSnapshotModel?

    private let persistence: PersistenceController
    private let service: NetWorthService

    init(persistence: PersistenceController) {
        self.persistence = persistence
        self.service = NetWorthService(persistence: persistence)
        reload()
    }

    func reload() {
        service.ensureMonthlySnapshot()
        let context = persistence.container.viewContext
        let request: NSFetchRequest<NetWorthSnapshot> = NetWorthSnapshot.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \NetWorthSnapshot.timestamp, ascending: false)]
        request.fetchLimit = 1
        let snapshot = try? context.fetch(request).first
        latestSnapshot = snapshot.map(NetWorthSnapshotModel.init)
    }
}
