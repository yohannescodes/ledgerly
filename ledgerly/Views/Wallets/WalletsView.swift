import SwiftUI
import Combine

struct WalletsView: View {
    @EnvironmentObject private var walletsStore: WalletsStore
    @EnvironmentObject private var netWorthStore: NetWorthStore
    @State private var showingAddForm = false
    @State private var walletToEdit: WalletModel?

    var body: some View {
        List {
            if walletsStore.wallets.isEmpty {
                Section {
                    VStack(spacing: 8) {
                        Text("No wallets yet")
                            .font(.headline)
                        Text("Add salary sources, checking accounts, or savings wallets to track balances and sync budgets.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
                }
            } else {
                walletSection(title: "Income Sources", wallets: incomeWallets)
                walletSection(title: "Accounts", wallets: accountWallets)
            }
        }
        .navigationTitle("Wallets")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingAddForm = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddForm) {
            WalletFormView(mode: .add) { input in
                walletsStore.addWallet(input: input)
                refreshNetWorth()
            }
        }
        .sheet(item: $walletToEdit) { wallet in
            WalletFormView(mode: .edit(wallet)) { input in
                walletsStore.updateWallet(walletID: wallet.id, input: input)
                refreshNetWorth()
            } onDelete: {
                walletsStore.deleteWallet(walletID: wallet.id)
                refreshNetWorth()
            }
        }
        .refreshable { walletsStore.reload() }
        .onAppear { walletsStore.reload() }
    }

    private var incomeWallets: [WalletModel] {
        walletsStore.wallets.filter { WalletKind.fromStored($0.walletType).isIncome }
    }

    private var accountWallets: [WalletModel] {
        walletsStore.wallets.filter { !WalletKind.fromStored($0.walletType).isIncome }
    }

    @ViewBuilder
    private func walletSection(title: String, wallets: [WalletModel]) -> some View {
        if !wallets.isEmpty {
            Section(title) {
                ForEach(wallets) { wallet in
                    WalletRow(wallet: wallet)
                        .contentShape(Rectangle())
                        .onTapGesture { walletToEdit = wallet }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                walletsStore.deleteWallet(walletID: wallet.id)
                                refreshNetWorth()
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
        }
    }

    private func refreshNetWorth() {
        netWorthStore.reload()
    }
}

private struct WalletRow: View {
    let wallet: WalletModel

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .frame(width: 32, height: 32)
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 4) {
                Text(wallet.name)
                    .font(.headline)
                Text(detailText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(formatCurrency(wallet.currentBalance, code: wallet.currencyCode))
                .font(.headline)
        }
        .padding(.vertical, 4)
    }

    private var iconName: String {
        wallet.iconName ?? WalletKind.fromStored(wallet.walletType).defaultIcon.rawValue
    }

    private var detailText: String {
        let kind = WalletKind.fromStored(wallet.walletType)
        return "\(kind.title) • \(wallet.currencyCode)"
    }

    private func formatCurrency(_ value: Decimal, code: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        return formatter.string(from: value as NSNumber) ?? "--"
    }
}

struct WalletFormView: View {
    enum Mode {
        case add
        case edit(WalletModel)

        var title: String {
            switch self {
            case .add: return "New Wallet"
            case .edit: return "Edit Wallet"
            }
        }
    }

    let mode: Mode
    let onSave: (WalletFormInput) -> Void
    let onDelete: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var input: WalletFormInput
    init(mode: Mode, onSave: @escaping (WalletFormInput) -> Void, onDelete: (() -> Void)? = nil) {
        self.mode = mode
        self.onSave = onSave
        self.onDelete = onDelete
        switch mode {
        case .add:
            _input = State(initialValue: WalletFormInput())
        case .edit(let wallet):
            _input = State(initialValue: WalletFormInput(wallet: wallet))
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Name", text: $input.name)
                    Picker("Type", selection: $input.kind) {
                        ForEach(WalletKind.allCases) { kind in
                            Text(kind.title).tag(kind)
                        }
                    }
                    NavigationLink {
                        CurrencyPickerView(
                            selectedCode: $input.currencyCode,
                            infoText: "Wallet currency"
                        )
                        .navigationTitle("Select Currency")
                    } label: {
                        HStack {
                            Text("Currency")
                            Spacer()
                            Text(currencyDisplay)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Balances") {
                    switch mode {
                    case .add:
                        DecimalTextField(title: "Initial Balance", value: $input.startingBalance)
                    case .edit:
                        DecimalTextField(title: "Starting Balance", value: $input.startingBalance)
                        DecimalTextField(title: "Current Balance", value: $input.currentBalance)
                    }
                }

                Section("Options") {
                    Toggle("Include in Net Worth", isOn: $input.includeInNetWorth)
                    iconPicker
                }

                if case .edit = mode, let onDelete {
                    Section {
                        Button(role: .destructive, action: {
                            onDelete()
                            dismiss()
                        }) {
                            Text("Delete Wallet")
                        }
                    }
                }
            }
            .navigationTitle(mode.title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: dismiss.callAsFunction)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!canSave)
                }
            }
        }
    }

    private var currencyDisplay: String {
        let code = input.currencyCode
        let option = CurrencyDataSource.all.first { $0.code == code }
        return option.map { "\($0.code) • \($0.name)" } ?? code
    }

    private var canSave: Bool {
        !input.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var iconPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Icon")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(WalletIcon.allCases) { icon in
                        Button(action: { input.icon = icon }) {
                            VStack {
                                Image(systemName: icon.rawValue)
                                    .font(.system(size: 20))
                                    .frame(width: 44, height: 44)
                                    .background(input.icon == icon ? Color.accentColor.opacity(0.2) : Color(.secondarySystemBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                Text(icon.label)
                                    .font(.caption2)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func save() {
        var payload = input
        if case .add = mode {
            payload.currentBalance = payload.startingBalance
        }
        onSave(payload)
        dismiss()
    }
}

#Preview {
    let persistence = PersistenceController.preview
    let walletsStore = WalletsStore(persistence: persistence)
    let netWorthStore = NetWorthStore(persistence: persistence)
    return NavigationStack {
        WalletsView()
            .environmentObject(walletsStore)
            .environmentObject(netWorthStore)
    }
}
