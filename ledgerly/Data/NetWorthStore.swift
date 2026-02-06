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
        service.ensureDailySnapshot()
        liveTotals = service.computeTotals()
        let context = persistence.container.viewContext
        let request: NSFetchRequest<NetWorthSnapshot> = NetWorthSnapshot.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \NetWorthSnapshot.timestamp, ascending: true)]
        do {
            let results = try context.fetch(request)
            let filteredResults: [NetWorthSnapshot]
            if let startDate = service.snapshotStartDate {
                filteredResults = results.filter { ($0.timestamp ?? .distantPast) >= startDate }
            } else {
                filteredResults = results
            }
            let models = filteredResults.map(NetWorthSnapshotModel.init)
            snapshots = models
            latestSnapshot = models.last
        let baseCurrency = CurrencyConverter.fromSettings(in: context).baseCurrency
        displaySnapshots = Self.makeDisplaySnapshots(
            base: models,
            liveTotals: liveTotals,
            baseCurrency: baseCurrency
        )
        } catch {
            assertionFailure("Failed to load net worth snapshots: \(error)")
            snapshots = []
            latestSnapshot = nil
            let baseCurrency = CurrencyConverter.fromSettings(in: context).baseCurrency
            displaySnapshots = Self.makeDisplaySnapshots(
                base: [],
                liveTotals: liveTotals,
                baseCurrency: baseCurrency
            )
        }
    }

    func fetchFxExposure() -> FxExposureSnapshot {
        service.computeFxExposure()
    }

    func fetchManualInvestmentPerformance() -> ManualInvestmentPerformanceSnapshot? {
        service.computeManualInvestmentPerformance()
    }

    func rebuildDailySnapshots(completion: @escaping (Result<Int, Error>) -> Void) {
        Task.detached { [service] in
            do {
                let count = try service.rebuildDailySnapshots()
                await MainActor.run {
                    self.reload()
                    completion(.success(count))
                }
            } catch {
                await MainActor.run {
                    completion(.failure(error))
                }
            }
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

    private static func makeDisplaySnapshots(
        base: [NetWorthSnapshotModel],
        liveTotals: NetWorthTotals?,
        baseCurrency: String
    ) -> [NetWorthSnapshotModel] {
        guard let totals = liveTotals else { return base }
        var combined = base
        let liveSnapshot = NetWorthSnapshotModel(
            timestamp: Date(),
            totals: totals,
            currencyCode: baseCurrency
        )
        if let last = combined.last,
           Calendar.current.isDate(last.timestamp, equalTo: liveSnapshot.timestamp, toGranularity: .minute) {
            return combined
        }
        combined.append(liveSnapshot)
        return combined
    }
}
