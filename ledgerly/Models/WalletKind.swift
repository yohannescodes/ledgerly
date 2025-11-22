import Foundation

enum WalletKind: String, CaseIterable, Identifiable {
    case income
    case checking
    case savings
    case cash
    case credit
    case investment
    case crypto
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .income: return "Income Wallet"
        case .checking: return "Checking Account"
        case .savings: return "Savings Account"
        case .cash: return "Cash"
        case .credit: return "Credit / Card"
        case .investment: return "Investment Account"
        case .crypto: return "Crypto Wallet"
        case .custom: return "Custom"
        }
    }

    var description: String {
        switch self {
        case .income:
            return "Use for salary or freelance payouts before distributing funds."
        case .checking:
            return "Primary day-to-day spending accounts."
        case .savings:
            return "Emergency and long-term savings accounts."
        case .cash:
            return "Physical cash you carry around."
        case .credit:
            return "Credit cards or charge accounts."
        case .investment:
            return "Brokerage or trading accounts tracked in net worth."
        case .crypto:
            return "Exchanges or wallets holding crypto/stablecoins pegged to fiat."
        case .custom:
            return "Any other type of wallet you want to track."
        }
    }

    var isIncome: Bool { self == .income }

    var defaultIcon: WalletIcon {
        switch self {
        case .income: return .briefcase
        case .checking: return .bank
        case .savings: return .piggy
        case .cash: return .banknote
        case .credit: return .credit
        case .investment: return .chart
        case .crypto: return .bolt
        case .custom: return .wallet
        }
    }

    var storedValue: String { rawValue }

    static func fromStored(_ value: String?) -> WalletKind {
        guard let value else { return .custom }
        if let kind = WalletKind(rawValue: value) {
            return kind
        }
        switch value.lowercased() {
        case "bank": return .checking
        case "salary": return .income
        case "crypto": return .crypto
        default: return .custom
        }
    }
}

enum WalletIcon: String, CaseIterable, Identifiable {
    case bank = "building.columns"
    case banknote = "banknote"
    case wallet = "wallet.pass"
    case credit = "creditcard"
    case piggy = "piggy.bank"
    case briefcase = "briefcase"
    case chart = "chart.line.uptrend.xyaxis"
    case bolt = "bolt.circle"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .bank: return "Bank"
        case .banknote: return "Cash"
        case .wallet: return "Wallet"
        case .credit: return "Credit"
        case .piggy: return "Savings"
        case .briefcase: return "Income"
        case .chart: return "Invest"
        case .bolt: return "Other"
        }
    }

    static func resolve(from name: String?) -> WalletIcon {
        guard let name, let icon = WalletIcon(rawValue: name) else { return .wallet }
        return icon
    }
}
