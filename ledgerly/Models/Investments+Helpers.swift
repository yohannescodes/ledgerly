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
    let sparklinePoints: [PricePoint]
}

struct PricePoint: Identifiable, Hashable {
    let id = UUID()
    let date: Date
    let value: Decimal
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
    let sales: [HoldingSaleModel]
}

struct HoldingSaleModel: Identifiable, Hashable {
    let id: NSManagedObjectID
    let identifier: String
    let date: Date
    let quantity: Decimal
    let price: Decimal
    let walletName: String?
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
    let investmentCoinID: String?
    let investmentSymbol: String?
    let investmentQuantity: Decimal
    let investmentCostPerUnit: Decimal
    let marketPrice: Decimal?
    let marketPriceCurrencyCode: String?
    let marketPriceUpdatedAt: Date?
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
    let id: UUID
    let objectID: NSManagedObjectID?
    let identifier: String
    let timestamp: Date
    let totalAssets: Decimal
    let totalLiabilities: Decimal
    let coreNetWorth: Decimal
    let tangibleNetWorth: Decimal
    let volatileAssets: Decimal
    let notes: String?

    var netWorth: Decimal { totalAssets - totalLiabilities }

    init(
        objectID: NSManagedObjectID? = nil,
        identifier: String = UUID().uuidString,
        timestamp: Date,
        totals: NetWorthTotals,
        notes: String? = nil
    ) {
        self.id = UUID()
        self.objectID = objectID
        self.identifier = identifier
        self.timestamp = timestamp
        self.totalAssets = totals.totalAssets
        self.totalLiabilities = totals.totalLiabilities
        self.coreNetWorth = totals.coreNetWorth
        self.tangibleNetWorth = totals.tangibleNetWorth
        self.volatileAssets = totals.volatileAssets
        self.notes = notes
    }
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
        if let snapshots = managedObject.snapshots as? Set<PriceSnapshot> {
            let sorted = snapshots.sorted { ($0.timestamp ?? .distantPast) < ($1.timestamp ?? .distantPast) }
            sparklinePoints = sorted.suffix(7).map { PricePoint(date: $0.timestamp ?? Date(), value: $0.price as Decimal? ?? .zero) }
        } else {
            sparklinePoints = []
        }
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
        sales = (managedObject.sales as? Set<HoldingSale> ?? [])
            .sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
            .map(HoldingSaleModel.init)
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
        investmentCoinID = managedObject.investmentCoinID
        investmentSymbol = managedObject.investmentSymbol
        investmentQuantity = managedObject.investmentQuantity as Decimal? ?? .zero
        investmentCostPerUnit = managedObject.investmentCostPerUnit as Decimal? ?? .zero
        marketPrice = managedObject.marketPrice as Decimal?
        marketPriceCurrencyCode = managedObject.marketPriceCurrencyCode
        marketPriceUpdatedAt = managedObject.marketPriceUpdatedAt
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

extension HoldingSaleModel {
    init(managedObject: HoldingSale) {
        id = managedObject.objectID
        identifier = managedObject.identifier ?? UUID().uuidString
        date = managedObject.date ?? Date()
        quantity = managedObject.quantity as Decimal? ?? .zero
        price = managedObject.price as Decimal? ?? .zero
        walletName = managedObject.walletName
    }
}

extension NetWorthSnapshotModel {
    init(managedObject: NetWorthSnapshot) {
        let totalAssets = managedObject.totalAssets as Decimal? ?? .zero
        let totalLiabilities = managedObject.totalLiabilities as Decimal? ?? .zero
        let totals = NetWorthTotals(
            totalAssets: totalAssets,
            totalLiabilities: totalLiabilities,
            netWorth: totalAssets - totalLiabilities,
            coreNetWorth: managedObject.coreNetWorth as Decimal? ?? .zero,
            tangibleNetWorth: managedObject.tangibleNetWorth as Decimal? ?? .zero,
            volatileAssets: managedObject.volatileAssets as Decimal? ?? .zero,
            walletAssets: .zero,
            manualAssets: .zero,
            receivables: .zero,
            stockInvestments: .zero,
            cryptoInvestments: .zero
        )
        self.init(
            objectID: managedObject.objectID,
            identifier: managedObject.identifier ?? UUID().uuidString,
            timestamp: managedObject.timestamp ?? Date(),
            totals: totals,
            notes: managedObject.notes
        )
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

extension HoldingSale {
    static func record(
        in context: NSManagedObjectContext,
        lot: HoldingLot?,
        quantity: Decimal,
        price: Decimal,
        walletName: String?
    ) -> HoldingSale {
        let sale = HoldingSale(context: context)
        sale.identifier = UUID().uuidString
        sale.date = Date()
        sale.quantity = NSDecimalNumber(decimal: quantity)
        sale.price = NSDecimalNumber(decimal: price)
        sale.walletName = walletName
        sale.lot = lot
        return sale
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
        volatility: Bool = false,
        investmentCoinID: String? = nil,
        investmentSymbol: String? = nil,
        investmentQuantity: Decimal? = nil,
        investmentCostPerUnit: Decimal? = nil,
        marketPrice: Decimal? = nil,
        marketPriceCurrencyCode: String? = nil
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
        asset.investmentCoinID = investmentCoinID
        asset.investmentSymbol = investmentSymbol
        if let investmentQuantity {
            asset.investmentQuantity = NSDecimalNumber(decimal: investmentQuantity)
        }
        if let investmentCostPerUnit {
            asset.investmentCostPerUnit = NSDecimalNumber(decimal: investmentCostPerUnit)
        }
        if let marketPrice {
            asset.marketPrice = NSDecimalNumber(decimal: marketPrice)
        }
        asset.marketPriceCurrencyCode = marketPriceCurrencyCode
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
        volatileAssets: Decimal,
        notes: String? = nil
    ) -> NetWorthSnapshot {
        let snapshot = NetWorthSnapshot(context: context)
        snapshot.identifier = UUID().uuidString
        snapshot.timestamp = Date()
        snapshot.totalAssets = NSDecimalNumber(decimal: totalAssets)
        snapshot.totalLiabilities = NSDecimalNumber(decimal: totalLiabilities)
        snapshot.coreNetWorth = NSDecimalNumber(decimal: coreNetWorth)
        snapshot.tangibleNetWorth = NSDecimalNumber(decimal: tangibleNetWorth)
        snapshot.volatileAssets = NSDecimalNumber(decimal: volatileAssets)
        snapshot.notes = notes
        return snapshot
    }
}
