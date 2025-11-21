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

            for _ in 0..<3 {
                let newItem = Item(context: context)
                newItem.timestamp = Date().addingTimeInterval(Double.random(in: -86400...0))
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
        seedDefaultsIfNeeded()
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

    private func seedDefaultsIfNeeded() {
        let context = container.viewContext
        context.perform { [weak context] in
            guard let context else { return }
            if AppSettings.fetchSingleton(in: context) != nil { return }

            _ = AppSettings.makeDefault(in: context)

            do {
                try context.save()
            } catch {
                let nsError = error as NSError
                fatalError("Failed to seed defaults: \(nsError), \(nsError.userInfo)")
            }
        }
    }
}
