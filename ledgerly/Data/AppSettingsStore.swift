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
    let exchangeRates: [String: Decimal]
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
        let normalized = code.uppercased()
        performMutation { settings in
            let previousBase = (settings.baseCurrencyCode ?? normalized).uppercased()
            let existingTable = ExchangeRateStorage.decode(settings.customExchangeRates)
            let rebased = ExchangeRateTransformer.rebase(
                existingTable,
                from: previousBase,
                to: normalized
            )
            settings.baseCurrencyCode = normalized
            settings.customExchangeRates = ExchangeRateStorage.encode(rebased)
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

    func updateExchangeRate(code: String, value: Decimal) {
        performMutation { settings in
            var table = ExchangeRateStorage.decode(settings.customExchangeRates)
            table[code.uppercased()] = value
            settings.customExchangeRates = ExchangeRateStorage.encode(table)
        }
    }

    func removeExchangeRate(code: String) {
        performMutation { settings in
            var table = ExchangeRateStorage.decode(settings.customExchangeRates)
            table.removeValue(forKey: code.uppercased())
            settings.customExchangeRates = ExchangeRateStorage.encode(table)
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
        exchangeRates = ExchangeRateStorage.decode(managedObject.customExchangeRates)
    }
}

enum ExchangeRateStorage {
    static func encode(_ table: [String: Decimal]) -> String {
        let normalized = table.reduce(into: [String: Double]()) { partial, item in
            partial[item.key.uppercased()] = NSDecimalNumber(decimal: item.value).doubleValue
        }
        guard let data = try? JSONSerialization.data(withJSONObject: normalized) else {
            return "{}"
        }
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    static func decode(_ stored: String?) -> [String: Decimal] {
        guard
            let stored,
            let data = stored.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Double]
        else { return [:] }
        var result: [String: Decimal] = [:]
        for (code, value) in json {
            result[code.uppercased()] = Decimal(value)
        }
        return result
    }
}

private enum ExchangeRateTransformer {
    static func rebase(_ table: [String: Decimal], from oldBase: String, to newBase: String) -> [String: Decimal] {
        let oldUpper = oldBase.uppercased()
        let newUpper = newBase.uppercased()
        var normalized = table.reduce(into: [String: Decimal]()) { partial, pair in
            partial[pair.key.uppercased()] = pair.value
        }
        // Remove any stray entry for the incoming base so UI never shows "1 BASE = ... BASE"
        normalized.removeValue(forKey: newUpper)
        guard oldUpper != newUpper else { return normalized }
        guard let factor = table.first(where: { $0.key.uppercased() == newUpper })?.value, factor != .zero else {
            // Can't translate existing rates without a reference; safest to drop them.
            return [:]
        }
        var rebased: [String: Decimal] = [:]
        for (code, value) in normalized {
            rebased[code] = value / factor
        }
        rebased[oldUpper] = Decimal(1) / factor
        return rebased
    }
}
