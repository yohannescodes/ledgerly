import CoreData
import Foundation
import SwiftUI
import Combine

@MainActor
final class NetWorthStore: ObservableObject {
    @Published private(set) var latestSnapshot: NetWorthSnapshotModel?
    @Published private(set) var snapshots: [NetWorthSnapshotModel] = []
    @Published private(set) var liveTotals: NetWorthTotals?
    @Published private(set) var displaySnapshots: [NetWorthSnapshotModel] = []

    private let persistence: PersistenceController
    private let service: NetWorthService
    private var cancellables = Set<AnyCancellable>()

    init(persistence: PersistenceController) {
        self.persistence = persistence
        self.service = NetWorthService(persistence: persistence)
        reload()
        NotificationCenter.default.publisher(for: .walletsDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.reload() }
            .store(in: &cancellables)
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
            displaySnapshots = Self.makeDisplaySnapshots(base: models, liveTotals: liveTotals)
        } catch {
            assertionFailure("Failed to load net worth snapshots: \(error)")
            snapshots = []
            latestSnapshot = nil
            displaySnapshots = Self.makeDisplaySnapshots(base: [], liveTotals: liveTotals)
        }
    }

    func updateSnapshotNotes(snapshot: NetWorthSnapshotModel, notes: String) {
        guard let objectID = snapshot.objectID else { return }
        let context = persistence.newBackgroundContext()
        context.perform {
            guard let managedSnapshot = try? context.existingObject(with: objectID) as? NetWorthSnapshot else { return }
            let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
            managedSnapshot.notes = trimmed.isEmpty ? nil : trimmed
            do {
                try context.save()
            } catch {
                assertionFailure("Failed to update snapshot notes: \(error)")
            }
            Task { @MainActor in self.reload() }
        }
    }

    private static func makeDisplaySnapshots(base: [NetWorthSnapshotModel], liveTotals: NetWorthTotals?) -> [NetWorthSnapshotModel] {
        guard let totals = liveTotals else { return base }
        var combined = base
        let liveSnapshot = NetWorthSnapshotModel(timestamp: Date(), totals: totals)
        if let last = combined.last,
           Calendar.current.isDate(last.timestamp, equalTo: liveSnapshot.timestamp, toGranularity: .minute) {
            return combined
        }
        combined.append(liveSnapshot)
        return combined
    }
}
