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
    let exchangeRateAPIKey: String?
    let stockApiKey: String?
    let cryptoApiKey: String?
}

enum ExchangeMode: String, CaseIterable, Identifiable, Hashable {
    case official
    case manual

    var id: String { rawValue }

    var title: String {
        switch self {
        case .official: return "Official"
        case .manual: return "Manual"
        }
    }

    var description: String {
        switch self {
        case .official:
            return "Fetches rates from ExchangeRate-API using your private API key."
        case .manual:
            return "You supply every rate manually for total control."
        }
    }

    init(storedValue: String?) {
        switch storedValue?.lowercased() {
        case ExchangeMode.manual.rawValue:
            self = .manual
        default:
            // Legacy or unknown values (including "parallel") fall back to official.
            self = .official
        }
    }
}

struct OfficialExchangeRateSyncResult {
    let baseCurrencyCode: String
    let updatedAt: Date
    let ratesCount: Int
}

enum OfficialExchangeRateSyncError: LocalizedError {
    case modeNotOfficial
    case missingAPIKey

    var errorDescription: String? {
        switch self {
        case .modeNotOfficial:
            return "Switch to Official mode to sync from ExchangeRate-API."
        case .missingAPIKey:
            return "Add your ExchangeRate-API key before syncing rates."
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
            let officialTable = ExchangeRateStorage.decode(settings.customExchangeRates)
            let manualTable = ExchangeRateStorage.decode(settings.manualExchangeRates)
            let rebasedOfficial = ExchangeRateTransformer.rebase(
                officialTable,
                from: previousBase,
                to: normalized
            )
            let rebasedManual = ExchangeRateTransformer.rebase(
                manualTable,
                from: previousBase,
                to: normalized
            )
            settings.baseCurrencyCode = normalized
            settings.customExchangeRates = ExchangeRateStorage.encode(rebasedOfficial)
            settings.manualExchangeRates = ExchangeRateStorage.encode(rebasedManual)
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
            let mode = ExchangeMode(storedValue: settings.exchangeMode)
            var table = Self.decodeRateTable(for: mode, settings: settings)
            table[code.uppercased()] = value
            Self.encodeRateTable(table, for: mode, settings: settings)
        }
    }

    func removeExchangeRate(code: String) {
        performMutation { settings in
            let mode = ExchangeMode(storedValue: settings.exchangeMode)
            var table = Self.decodeRateTable(for: mode, settings: settings)
            table.removeValue(forKey: code.uppercased())
            Self.encodeRateTable(table, for: mode, settings: settings)
        }
    }

    func updateExchangeRateAPIKey(_ apiKey: String?) {
        performMutation { settings in
            settings.exchangeRateApiKey = Self.normalizedAPIKey(apiKey)
        }
    }

    func clearExchangeRateAPIKey() {
        updateExchangeRateAPIKey(nil)
    }

    func syncOfficialExchangeRates(
        apiKeyOverride: String? = nil,
        baseCurrencyOverride: String? = nil,
        ignoreMode: Bool = false
    ) async throws -> OfficialExchangeRateSyncResult {
        let resolvedAPIKey = Self.normalizedAPIKey(apiKeyOverride)
        let resolvedBaseCurrencyCode = normalizedCurrencyCode(baseCurrencyOverride)
        let resolved = try await resolveOfficialRateConfiguration(
            apiKeyOverride: resolvedAPIKey,
            baseCurrencyOverride: resolvedBaseCurrencyCode,
            ignoreMode: ignoreMode
        )
        let payload = try await ExchangeRateAPIClient().fetchLatestRates(
            apiKey: resolved.apiKey,
            baseCurrencyCode: resolved.baseCurrencyCode
        )
        let baseCode = payload.baseCode.uppercased()
        var normalizedRates: [String: Decimal] = [:]
        for (code, apiRate) in payload.conversionRates {
            let upperCode = code.uppercased()
            if upperCode == baseCode { continue }
            if apiRate == .zero { continue }
            // ExchangeRate-API returns: 1 base = X target.
            // App converter expects: 1 target = X base.
            normalizedRates[upperCode] = Decimal(1) / apiRate
        }

        let context = persistence.newBackgroundContext()
        try await context.perform {
            let settings = AppSettings.fetchSingleton(in: context) ?? AppSettings.makeDefault(in: context)
            settings.baseCurrencyCode = resolved.baseCurrencyCode
            settings.customExchangeRates = ExchangeRateStorage.encode(normalizedRates)
            settings.exchangeRateApiKey = resolved.apiKey
            settings.lastUpdated = payload.timeLastUpdateUTC ?? Date()
            try context.save()
        }

        refresh()
        return OfficialExchangeRateSyncResult(
            baseCurrencyCode: resolved.baseCurrencyCode,
            updatedAt: payload.timeLastUpdateUTC ?? Date(),
            ratesCount: normalizedRates.count
        )
    }

    func updateMarketDataAPIKeys(stock stockApiKey: String, crypto cryptoApiKey: String) {
        performMutation { settings in
            settings.stockApiKey = Self.normalizedAPIKey(stockApiKey)
            settings.cryptoApiKey = Self.normalizedAPIKey(cryptoApiKey)
        }
    }

    func clearMarketDataAPIKeys() {
        performMutation { settings in
            settings.stockApiKey = nil
            settings.cryptoApiKey = nil
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

    fileprivate static func normalizedAPIKey(_ key: String?) -> String? {
        let trimmed = key?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func decodeRateTable(for mode: ExchangeMode, settings: AppSettings) -> [String: Decimal] {
        switch mode {
        case .official:
            return ExchangeRateStorage.decode(settings.customExchangeRates)
        case .manual:
            return ExchangeRateStorage.decode(settings.manualExchangeRates)
        }
    }

    private static func encodeRateTable(_ table: [String: Decimal], for mode: ExchangeMode, settings: AppSettings) {
        let encoded = ExchangeRateStorage.encode(table)
        switch mode {
        case .official:
            settings.customExchangeRates = encoded
        case .manual:
            settings.manualExchangeRates = encoded
        }
    }

    private func resolveOfficialRateConfiguration(
        apiKeyOverride: String?,
        baseCurrencyOverride: String?,
        ignoreMode: Bool
    ) async throws -> OfficialRateConfiguration {
        let context = persistence.container.viewContext
        return try await context.perform {
            let settings = AppSettings.fetchSingleton(in: context) ?? AppSettings.makeDefault(in: context)
            let mode = ExchangeMode(storedValue: settings.exchangeMode)
            guard ignoreMode || mode == .official else {
                throw OfficialExchangeRateSyncError.modeNotOfficial
            }
            guard let apiKey = apiKeyOverride ?? Self.normalizedAPIKey(settings.exchangeRateApiKey) else {
                throw OfficialExchangeRateSyncError.missingAPIKey
            }
            let baseCurrencyCode = baseCurrencyOverride ?? (settings.baseCurrencyCode ?? "USD").uppercased()
            return OfficialRateConfiguration(baseCurrencyCode: baseCurrencyCode, apiKey: apiKey)
        }
    }

    private func normalizedCurrencyCode(_ code: String?) -> String? {
        let trimmed = code?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed.uppercased()
    }

    private struct OfficialRateConfiguration {
        let baseCurrencyCode: String
        let apiKey: String
    }
}

private extension AppSettingsSnapshot {
    init(managedObject: AppSettings) {
        baseCurrencyCode = managedObject.baseCurrencyCode ?? "USD"
        let mode = ExchangeMode(storedValue: managedObject.exchangeMode)
        exchangeMode = mode
        cloudSyncEnabled = managedObject.cloudSyncEnabled
        hasCompletedOnboarding = managedObject.hasCompletedOnboarding
        priceRefreshIntervalMinutes = Int(managedObject.priceRefreshIntervalMinutes)
        notificationsEnabled = managedObject.notificationsEnabled
        dashboardWidgets = DashboardWidgetStorage.decode(managedObject.dashboardWidgets)
        switch mode {
        case .official:
            exchangeRates = ExchangeRateStorage.decode(managedObject.customExchangeRates)
        case .manual:
            exchangeRates = ExchangeRateStorage.decode(managedObject.manualExchangeRates)
        }
        exchangeRateAPIKey = AppSettingsStore.normalizedAPIKey(managedObject.exchangeRateApiKey)
        stockApiKey = AppSettingsStore.normalizedAPIKey(managedObject.stockApiKey)
        cryptoApiKey = AppSettingsStore.normalizedAPIKey(managedObject.cryptoApiKey)
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
