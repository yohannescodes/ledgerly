import Foundation

struct WalletFormInput {
    var name: String
    var kind: WalletKind
    var currencyCode: String
    var startingBalance: Decimal
    var currentBalance: Decimal
    var includeInNetWorth: Bool
    var icon: WalletIcon

    init(
        name: String = "",
        kind: WalletKind = .checking,
        currencyCode: String = Locale.current.currency?.identifier ?? "USD",
        startingBalance: Decimal = .zero,
        currentBalance: Decimal? = nil,
        includeInNetWorth: Bool = true,
        icon: WalletIcon = .wallet
    ) {
        self.name = name
        self.kind = kind
        self.currencyCode = currencyCode
        self.startingBalance = startingBalance
        self.currentBalance = currentBalance ?? startingBalance
        self.includeInNetWorth = includeInNetWorth
        self.icon = icon
    }

    init(wallet: WalletModel) {
        self.name = wallet.name
        self.kind = WalletKind.fromStored(wallet.walletType)
        self.currencyCode = wallet.currencyCode
        self.startingBalance = wallet.startingBalance
        self.currentBalance = wallet.currentBalance
        self.includeInNetWorth = wallet.includeInNetWorth
        self.icon = WalletIcon.resolve(from: wallet.iconName)
    }
}
