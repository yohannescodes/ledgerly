import CoreData
import Foundation
import Combine

struct InvestmentAccountModel: Identifiable, Hashable {
    let id: NSManagedObjectID
    let identifier: String
    let name: String
    let institution: String?
    let accountType: String
    let currencyCode: String
    let includeInNetWorth: Bool
    let holdings: [HoldingLotModel]
    let totalCost: Decimal
    let marketValue: Decimal
    let unrealizedGain: Decimal
    let gainPercent: Decimal?
}

struct InvestmentAssetModel: Identifiable, Hashable {
    let id: NSManagedObjectID
    let identifier: String
    let symbol: String
    let assetType: String
    let name: String
    let exchange: String?
    let currencyCode: String
}

struct HoldingLotModel: Identifiable, Hashable {
    let id: NSManagedObjectID
    let identifier: String
    let quantity: Decimal
    let costPerUnit: Decimal
    let acquiredDate: Date
    let asset: InvestmentAssetModel
    let latestPrice: Decimal?
    let marketValue: Decimal
    let costBasis: Decimal
    let unrealizedGain: Decimal
    let percentChange: Decimal?
}

struct PriceSnapshotModel: Identifiable, Hashable {
    let id: NSManagedObjectID
    let price: Decimal
    let currencyCode: String
    let provider: String
    let timestamp: Date
}

struct ManualAssetModel: Identifiable, Hashable {
    let id: NSManagedObjectID
    let identifier: String
    let name: String
    let type: String
    let value: Decimal
    let currencyCode: String
    let includeInCore: Bool
    let includeInTangible: Bool
    let volatility: Bool
}

struct ManualLiabilityModel: Identifiable, Hashable {
    let id: NSManagedObjectID
    let identifier: String
    let name: String
    let type: String
    let balance: Decimal
    let currencyCode: String
}

struct NetWorthSnapshotModel: Identifiable, Hashable {
    let id: NSManagedObjectID
    let identifier: String
    let timestamp: Date
    let totalAssets: Decimal
    let totalLiabilities: Decimal
    let coreNetWorth: Decimal
    let tangibleNetWorth: Decimal
    let volatileAssets: Decimal
}

extension InvestmentAccountModel {
    init(managedObject: InvestmentAccount) {
        id = managedObject.objectID
        identifier = managedObject.identifier ?? UUID().uuidString
        name = managedObject.name ?? "Account"
        institution = managedObject.institution
        accountType = managedObject.accountType ?? "brokerage"
        currencyCode = managedObject.currencyCode ?? "USD"
        includeInNetWorth = managedObject.includeInNetWorth
        holdings = (managedObject.holdings as? Set<HoldingLot> ?? [])
            .map(HoldingLotModel.init)
            .sorted { $0.acquiredDate < $1.acquiredDate }
        totalCost = holdings.reduce(.zero) { $0 + $1.costBasis }
        marketValue = holdings.reduce(.zero) { $0 + $1.marketValue }
        unrealizedGain = marketValue - totalCost
        gainPercent = totalCost == .zero ? nil : ((unrealizedGain / totalCost) * 100)
    }
}

extension InvestmentAssetModel {
    init(managedObject: InvestmentAsset) {
        id = managedObject.objectID
        identifier = managedObject.identifier ?? UUID().uuidString
        symbol = managedObject.symbol ?? "--"
        assetType = managedObject.assetType ?? "stock"
        name = managedObject.name ?? symbol
        exchange = managedObject.exchange
        currencyCode = managedObject.currencyCode ?? "USD"
    }
}

extension HoldingLotModel {
    init(managedObject: HoldingLot) {
        id = managedObject.objectID
        identifier = managedObject.identifier ?? UUID().uuidString
        quantity = managedObject.quantity as Decimal? ?? .zero
        costPerUnit = managedObject.costPerUnit as Decimal? ?? .zero
        acquiredDate = managedObject.acquiredDate ?? Date()
        guard let assetObject = managedObject.asset else {
            fatalError("HoldingLot missing asset reference")
        }
        asset = InvestmentAssetModel(managedObject: assetObject)
        latestPrice = Self.latestSnapshot(for: assetObject)
        costBasis = quantity * costPerUnit
        if let price = latestPrice {
            marketValue = price * quantity
        } else {
            marketValue = costBasis
        }
        unrealizedGain = marketValue - costBasis
        percentChange = costBasis == .zero ? nil : ((unrealizedGain / costBasis) * 100)
    }

    private static func latestSnapshot(for asset: InvestmentAsset) -> Decimal? {
        guard let snapshots = asset.snapshots as? Set<PriceSnapshot> else { return nil }
        let latest = snapshots.sorted { ($0.timestamp ?? .distantPast) > ($1.timestamp ?? .distantPast) }.first
        return latest?.price as Decimal?
    }
}

extension PriceSnapshotModel {
    init(managedObject: PriceSnapshot) {
        id = managedObject.objectID
        price = managedObject.price as Decimal? ?? .zero
        currencyCode = managedObject.currencyCode ?? "USD"
        provider = managedObject.provider ?? ""
        timestamp = managedObject.timestamp ?? Date()
    }
}

extension ManualAssetModel {
    init(managedObject: ManualAsset) {
        id = managedObject.objectID
        identifier = managedObject.identifier ?? UUID().uuidString
        name = managedObject.name ?? "Asset"
        type = managedObject.type ?? "tangible"
        value = managedObject.value as Decimal? ?? .zero
        currencyCode = managedObject.currencyCode ?? "USD"
        includeInCore = managedObject.includeInCore
        includeInTangible = managedObject.includeInTangible
        volatility = managedObject.volatility
    }
}

extension ManualLiabilityModel {
    init(managedObject: ManualLiability) {
        id = managedObject.objectID
        identifier = managedObject.identifier ?? UUID().uuidString
        name = managedObject.name ?? "Liability"
        type = managedObject.type ?? "loan"
        balance = managedObject.balance as Decimal? ?? .zero
        currencyCode = managedObject.currencyCode ?? "USD"
    }
}

extension NetWorthSnapshotModel {
    init(managedObject: NetWorthSnapshot) {
        id = managedObject.objectID
        identifier = managedObject.identifier ?? UUID().uuidString
        timestamp = managedObject.timestamp ?? Date()
        totalAssets = managedObject.totalAssets as Decimal? ?? .zero
        totalLiabilities = managedObject.totalLiabilities as Decimal? ?? .zero
        coreNetWorth = managedObject.coreNetWorth as Decimal? ?? .zero
        tangibleNetWorth = managedObject.tangibleNetWorth as Decimal? ?? .zero
        volatileAssets = managedObject.volatileAssets as Decimal? ?? .zero
    }
}

// MARK: - Creation Helpers

extension InvestmentAccount {
    static func create(
        in context: NSManagedObjectContext,
        identifier: String = UUID().uuidString,
        name: String,
        institution: String?,
        accountType: String,
        currencyCode: String,
        includeInNetWorth: Bool = true
    ) -> InvestmentAccount {
        let account = InvestmentAccount(context: context)
        account.identifier = identifier
        account.name = name
        account.institution = institution
        account.accountType = accountType
        account.currencyCode = currencyCode
        account.includeInNetWorth = includeInNetWorth
        account.createdAt = Date()
        account.updatedAt = Date()
        return account
    }
}

extension InvestmentAsset {
    static func create(
        in context: NSManagedObjectContext,
        identifier: String = UUID().uuidString,
        symbol: String,
        assetType: String,
        name: String,
        exchange: String?,
        currencyCode: String
    ) -> InvestmentAsset {
        let asset = InvestmentAsset(context: context)
        asset.identifier = identifier
        asset.symbol = symbol
        asset.assetType = assetType
        asset.name = name
        asset.exchange = exchange
        asset.currencyCode = currencyCode
        return asset
    }
}

extension HoldingLot {
    static func create(
        in context: NSManagedObjectContext,
        identifier: String = UUID().uuidString,
        quantity: Decimal,
        costPerUnit: Decimal,
        acquiredDate: Date,
        account: InvestmentAccount,
        asset: InvestmentAsset,
        fee: Decimal? = nil
    ) -> HoldingLot {
        let lot = HoldingLot(context: context)
        lot.identifier = identifier
        lot.quantity = NSDecimalNumber(decimal: quantity)
        lot.costPerUnit = NSDecimalNumber(decimal: costPerUnit)
        lot.acquiredDate = acquiredDate
        lot.account = account
        lot.asset = asset
        if let fee { lot.fee = NSDecimalNumber(decimal: fee) }
        return lot
    }
}

extension PriceSnapshot {
    static func record(
        in context: NSManagedObjectContext,
        asset: InvestmentAsset,
        price: Decimal,
        currencyCode: String,
        provider: String
    ) -> PriceSnapshot {
        let snapshot = PriceSnapshot(context: context)
        snapshot.identifier = UUID().uuidString
        snapshot.asset = asset
        snapshot.price = NSDecimalNumber(decimal: price)
        snapshot.currencyCode = currencyCode
        snapshot.provider = provider
        snapshot.timestamp = Date()
        snapshot.isStale = false
        return snapshot
    }
}

extension ManualAsset {
    static func create(
        in context: NSManagedObjectContext,
        name: String,
        type: String,
        value: Decimal,
        currencyCode: String,
        includeInCore: Bool = true,
        includeInTangible: Bool = true,
        volatility: Bool = false
    ) -> ManualAsset {
        let asset = ManualAsset(context: context)
        asset.identifier = UUID().uuidString
        asset.name = name
        asset.type = type
        asset.value = NSDecimalNumber(decimal: value)
        asset.currencyCode = currencyCode
        asset.valuationDate = Date()
        asset.includeInCore = includeInCore
        asset.includeInTangible = includeInTangible
        asset.volatility = volatility
        return asset
    }
}

extension ManualLiability {
    static func create(
        in context: NSManagedObjectContext,
        name: String,
        type: String,
        balance: Decimal,
        currencyCode: String
    ) -> ManualLiability {
        let liability = ManualLiability(context: context)
        liability.identifier = UUID().uuidString
        liability.name = name
        liability.type = type
        liability.balance = NSDecimalNumber(decimal: balance)
        liability.currencyCode = currencyCode
        liability.dueDate = Calendar.current.date(byAdding: .month, value: 1, to: Date())
        return liability
    }
}

extension NetWorthSnapshot {
    static func create(
        in context: NSManagedObjectContext,
        totalAssets: Decimal,
        totalLiabilities: Decimal,
        coreNetWorth: Decimal,
        tangibleNetWorth: Decimal,
        volatileAssets: Decimal
    ) -> NetWorthSnapshot {
        let snapshot = NetWorthSnapshot(context: context)
        snapshot.identifier = UUID().uuidString
        snapshot.timestamp = Date()
        snapshot.totalAssets = NSDecimalNumber(decimal: totalAssets)
        snapshot.totalLiabilities = NSDecimalNumber(decimal: totalLiabilities)
        snapshot.coreNetWorth = NSDecimalNumber(decimal: coreNetWorth)
        snapshot.tangibleNetWorth = NSDecimalNumber(decimal: tangibleNetWorth)
        snapshot.volatileAssets = NSDecimalNumber(decimal: volatileAssets)
        return snapshot
    }
}
