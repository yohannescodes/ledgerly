import Combine
import CoreData
import Foundation

extension AppSettings {
    static let singletonIdentifier = "app_settings_singleton"

    static func fetchSingleton(in context: NSManagedObjectContext) -> AppSettings? {
        let request: NSFetchRequest<AppSettings> = AppSettings.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "identifier == %@", AppSettings.singletonIdentifier)
        do {
            return try context.fetch(request).first
        } catch {
            assertionFailure("Failed to fetch AppSettings: \(error)")
            return nil
        }
    }

    static func makeDefault(in context: NSManagedObjectContext) -> AppSettings {
        let settings = AppSettings(context: context)
        settings.identifier = AppSettings.singletonIdentifier
        settings.baseCurrencyCode = Locale.current.currency?.identifier ?? "USD"
        settings.exchangeMode = "official"
        settings.cloudSyncEnabled = false
        settings.hasCompletedOnboarding = false
        settings.notificationsEnabled = true
        settings.priceRefreshIntervalMinutes = 30
        settings.lastUpdated = Date()
        settings.customExchangeRates = "{}"
        settings.manualExchangeRates = "{}"
        settings.exchangeRateApiKey = nil
        settings.dashboardWidgets = DashboardWidgetStorage.encode(DashboardWidget.defaultOrder)
        return settings
    }
}
