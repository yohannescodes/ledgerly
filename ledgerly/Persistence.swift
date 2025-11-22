//
//  Persistence.swift
//  ledgerly
//
//  Created by Yohannes Haile on 11/21/25.
//

import CoreData

final class PersistenceController {
    static let shared = PersistenceController()

    @MainActor
    static let preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        let context = controller.container.viewContext
        context.performAndWait {
            if AppSettings.fetchSingleton(in: context) == nil {
                let settings = AppSettings.makeDefault(in: context)
                settings.hasCompletedOnboarding = true
            }
        }

        do {
            try context.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }

        return controller
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "ledgerly")
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }

        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }

        configureContexts()
        ensureBaseEntities()
    }

    func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        context.automaticallyMergesChangesFromParent = true
        return context
    }

    private func configureContexts() {
        let context = container.viewContext
        context.automaticallyMergesChangesFromParent = true
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        context.shouldDeleteInaccessibleFaults = true
        context.undoManager = nil
    }

    private func ensureBaseEntities() {
        let context = container.viewContext
        context.perform {
            if AppSettings.fetchSingleton(in: context) == nil {
                _ = AppSettings.makeDefault(in: context)
            }
            CategoryDefaults.ensureDefaults(in: context)
            do {
                try context.save()
            } catch {
                assertionFailure("Failed to ensure base entities: \(error)")
            }
        }
    }

    private func seedNetWorthSnapshotIfNeeded(in context: NSManagedObjectContext) {
        let snapshotRequest: NSFetchRequest<NetWorthSnapshot> = NetWorthSnapshot.fetchRequest()
        snapshotRequest.fetchLimit = 1
        let count = (try? context.count(for: snapshotRequest)) ?? 0
        guard count == 0 else { return }
        let service = NetWorthService(persistence: self)
        let totals = service.computeTotals()
        _ = NetWorthSnapshot.create(
            in: context,
            totalAssets: totals.totalAssets,
            totalLiabilities: totals.totalLiabilities,
            coreNetWorth: totals.coreNetWorth,
            tangibleNetWorth: totals.tangibleNetWorth,
            volatileAssets: totals.volatileAssets
        )
    }

}
