import CoreData
import Foundation
import SwiftUI
import Combine

@MainActor
final class NetWorthStore: ObservableObject {
    @Published private(set) var latestSnapshot: NetWorthSnapshotModel?
    @Published private(set) var snapshots: [NetWorthSnapshotModel] = []
    @Published private(set) var liveTotals: NetWorthTotals?

    private let persistence: PersistenceController
    private let service: NetWorthService

    init(persistence: PersistenceController) {
        self.persistence = persistence
        self.service = NetWorthService(persistence: persistence)
        reload()
    }

    func reload() {
        service.ensureMonthlySnapshot()
        liveTotals = service.computeTotals()
        let context = persistence.container.viewContext
        let request: NSFetchRequest<NetWorthSnapshot> = NetWorthSnapshot.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \NetWorthSnapshot.timestamp, ascending: true)]
        do {
            let results = try context.fetch(request)
            let models = results.map(NetWorthSnapshotModel.init)
            snapshots = models
            latestSnapshot = models.last
        } catch {
            assertionFailure("Failed to load net worth snapshots: \(error)")
            snapshots = []
            latestSnapshot = nil
        }
    }

    func updateSnapshotNotes(snapshotID: NSManagedObjectID, notes: String) {
        let context = persistence.newBackgroundContext()
        context.perform {
            guard let snapshot = try? context.existingObject(with: snapshotID) as? NetWorthSnapshot else { return }
            let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
            snapshot.notes = trimmed.isEmpty ? nil : trimmed
            do {
                try context.save()
            } catch {
                assertionFailure("Failed to update snapshot notes: \(error)")
            }
            Task { @MainActor in self.reload() }
        }
    }
}
