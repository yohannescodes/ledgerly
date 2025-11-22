import Combine
import CoreData
import Foundation
import SwiftUI

struct AppSettingsSnapshot: Equatable {
    let baseCurrencyCode: String
    let exchangeMode: ExchangeMode
    let cloudSyncEnabled: Bool
    let hasCompletedOnboarding: Bool
    let priceRefreshIntervalMinutes: Int
    let notificationsEnabled: Bool
    let dashboardWidgets: [DashboardWidget]
}

enum ExchangeMode: String, CaseIterable, Identifiable, Hashable {
    case official
    case parallel
    case manual

    var id: String { rawValue }

    var title: String {
        switch self {
        case .official: return "Official"
        case .parallel: return "Parallel"
        case .manual: return "Manual"
        }
    }

    var description: String {
        switch self {
        case .official:
            return "Uses trusted FX feeds suited for banks and salary accounts."
        case .parallel:
            return "Tracks unofficial/parallel rates for volatile markets."
        case .manual:
            return "You supply every rate manually for total control."
        }
    }
}

@MainActor
final class AppSettingsStore: ObservableObject {
    @Published private(set) var snapshot: AppSettingsSnapshot

    private let persistence: PersistenceController

    init(persistence: PersistenceController) {
        self.persistence = persistence
        let context = persistence.container.viewContext
        var settings = AppSettings.fetchSingleton(in: context)
        if settings == nil {
            settings = AppSettings.makeDefault(in: context)
            try? context.save()
        }

        self.snapshot = AppSettingsSnapshot(managedObject: settings!)
    }

    func refresh() {
        let context = persistence.container.viewContext
        var updatedSnapshot: AppSettingsSnapshot?
        context.performAndWait {
            guard let settings = AppSettings.fetchSingleton(in: context) else { return }
            updatedSnapshot = AppSettingsSnapshot(managedObject: settings)
        }

        if let newValue = updatedSnapshot {
            snapshot = newValue
        }
    }

    func markOnboardingComplete() {
        performMutation { settings in
            settings.hasCompletedOnboarding = true
        }
    }

    func updateBaseCurrency(code: String) {
        performMutation { settings in
            settings.baseCurrencyCode = code
        }
    }

    func updateExchangeMode(_ mode: ExchangeMode) {
        performMutation { settings in
            settings.exchangeMode = mode.rawValue
        }
    }

    func toggleCloudSync(_ enabled: Bool) {
        performMutation { settings in
            settings.cloudSyncEnabled = enabled
        }
    }

    func updateNotifications(_ enabled: Bool) {
        performMutation { settings in
            settings.notificationsEnabled = enabled
        }
    }

    func updateDashboardWidgets(_ widgets: [DashboardWidget]) {
        performMutation { settings in
            settings.dashboardWidgets = DashboardWidgetStorage.encode(widgets)
        }
    }

    private func performMutation(_ block: @escaping (AppSettings) -> Void) {
        let context = persistence.newBackgroundContext()
        context.perform {
            let settings = AppSettings.fetchSingleton(in: context) ?? AppSettings.makeDefault(in: context)
            block(settings)
            settings.lastUpdated = Date()

            do {
                try context.save()
            } catch {
                assertionFailure("Failed to persist AppSettings: \(error)")
            }

            Task { @MainActor [weak self] in
                self?.refresh()
            }
        }
    }
}

private extension AppSettingsSnapshot {
    init(managedObject: AppSettings) {
        baseCurrencyCode = managedObject.baseCurrencyCode ?? "USD"
        exchangeMode = ExchangeMode(rawValue: managedObject.exchangeMode ?? "official") ?? .official
        cloudSyncEnabled = managedObject.cloudSyncEnabled
        hasCompletedOnboarding = managedObject.hasCompletedOnboarding
        priceRefreshIntervalMinutes = Int(managedObject.priceRefreshIntervalMinutes)
        notificationsEnabled = managedObject.notificationsEnabled
        dashboardWidgets = DashboardWidgetStorage.decode(managedObject.dashboardWidgets)
    }
}
