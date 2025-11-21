import SwiftUI

/// Multi-step onboarding matching the PRD: welcome, base currency, exchange mode, cloud sync, summary.
struct OnboardingView: View {
    @EnvironmentObject private var appSettingsStore: AppSettingsStore

    @State private var step: OnboardingStep = .welcome
    @State private var selectedCurrency: String
    @State private var selectedExchangeMode: ExchangeMode
    @State private var cloudSyncEnabled: Bool
    @State private var currencySearchText = ""
    @State private var isSaving = false

    init(initialSnapshot: AppSettingsSnapshot) {
        _selectedCurrency = State(initialValue: initialSnapshot.baseCurrencyCode)
        _selectedExchangeMode = State(initialValue: initialSnapshot.exchangeMode)
        _cloudSyncEnabled = State(initialValue: initialSnapshot.cloudSyncEnabled)
    }

    var body: some View {
        VStack(spacing: 28) {
            OnboardingHeader(step: step)
            StepContentView(
                step: step,
                selectedCurrency: $selectedCurrency,
                currencySearchText: $currencySearchText,
                selectedExchangeMode: $selectedExchangeMode,
                cloudSyncEnabled: $cloudSyncEnabled,
                currencySuggestions: CurrencyDataSource.suggested,
                allCurrencies: CurrencyDataSource.all
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            HStack(spacing: 16) {
                if step != .welcome {
                    Button("Back", action: goBack)
                        .buttonStyle(.borderless)
                }
                Spacer()
                Button(action: advance) {
                    if step == .summary {
                        HStack(spacing: 8) {
                            if isSaving { ProgressView().tint(.white) }
                            Text("Finish Setup")
                        }
                    } else {
                        Text("Continue")
                    }
                }
                .disabled(!canContinue || isSaving)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .animation(.easeInOut, value: step)
    }

    // MARK: - Flow Control

    private var canContinue: Bool {
        switch step {
        case .welcome, .exchangeMode, .cloudSync, .summary:
            return true
        case .currency:
            return !selectedCurrency.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    private func goBack() {
        guard let previous = step.previous else { return }
        step = previous
    }

    private func advance() {
        guard !isSaving else { return }
        if step == .summary {
            completeOnboarding()
            return
        }
        if let next = step.next {
            step = next
        }
    }

    private func completeOnboarding() {
        isSaving = true
        appSettingsStore.updateBaseCurrency(code: selectedCurrency)
        appSettingsStore.updateExchangeMode(selectedExchangeMode)
        appSettingsStore.toggleCloudSync(cloudSyncEnabled)
        appSettingsStore.markOnboardingComplete()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            isSaving = false
        }
    }
}

// MARK: - Header

private struct OnboardingHeader: View {
    let step: OnboardingStep

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(step.header)
                .font(.largeTitle.weight(.bold))
            Text(step.subtitle)
                .foregroundStyle(.secondary)
            ProgressView(value: step.progress, total: 1)
                .tint(.accentColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Step Content

private struct StepContentView: View {
    let step: OnboardingStep

    @Binding var selectedCurrency: String
    @Binding var currencySearchText: String
    @Binding var selectedExchangeMode: ExchangeMode
    @Binding var cloudSyncEnabled: Bool

    let currencySuggestions: [CurrencyOption]
    let allCurrencies: [CurrencyOption]

    var body: some View {
        switch step {
        case .welcome:
            WelcomeView()
        case .currency:
            CurrencyStep(
                selectedCurrency: $selectedCurrency,
                searchText: $currencySearchText,
                suggestions: currencySuggestions,
                options: filteredCurrencies
            )
        case .exchangeMode:
            ExchangeModeStep(selectedMode: $selectedExchangeMode)
        case .cloudSync:
            CloudSyncStep(isEnabled: $cloudSyncEnabled)
        case .summary:
            SummaryStep(
                currency: selectedCurrency,
                exchangeMode: selectedExchangeMode,
                syncEnabled: cloudSyncEnabled
            )
        }
    }

    private var filteredCurrencies: [CurrencyOption] {
        let trimmed = currencySearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return allCurrencies }
        return allCurrencies.filter { option in
            option.code.localizedCaseInsensitiveContains(trimmed) ||
            option.name.localizedCaseInsensitiveContains(trimmed)
        }
    }
}

private struct WelcomeView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Ledgerly keeps everything offline by default. You control when data syncs.")
            Label("Offline-first, no ads, no trackers.", systemImage: "lock.shield")
            Label("Track salary, cash, bank, and freelance wallets.", systemImage: "wallet.pass")
            Label("Budgeting, investments, and net worth in one place.", systemImage: "chart.line.uptrend.xyaxis")
            Spacer()
        }
    }
}

private struct CurrencyStep: View {
    @Binding var selectedCurrency: String
    @Binding var searchText: String

    let suggestions: [CurrencyOption]
    let options: [CurrencyOption]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Choose a base currency for reports. Wallets can still hold any currency.")
                .foregroundStyle(.secondary)
            TextField("Search currency", text: $searchText)
                .textFieldStyle(.roundedBorder)
            if !suggestions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(suggestions) { option in
                            Button {
                                selectedCurrency = option.code
                            } label: {
                                Text(option.code)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(selectedCurrency == option.code ? Color.accentColor.opacity(0.2) : Color(.systemGray5))
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(options) { option in
                        Button {
                            selectedCurrency = option.code
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(option.name)
                                    Text(option.code)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if selectedCurrency == option.code {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.accentColor)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                        Divider()
                    }
                }
            }
        }
    }
}

private struct ExchangeModeStep: View {
    @Binding var selectedMode: ExchangeMode
    private let modes = ExchangeMode.allCases

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Pick how exchange rates behave globally. Override per wallet later.")
                .foregroundStyle(.secondary)
            ForEach(modes) { mode in
                Button {
                    selectedMode = mode
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(mode.title)
                                .font(.headline)
                            Spacer()
                            if selectedMode == mode {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.accentColor)
                            }
                        }
                        Text(mode.description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(selectedMode == mode ? Color.accentColor : Color.clear, lineWidth: 2)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct CloudSyncStep: View {
    @Binding var isEnabled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Toggle(isOn: $isEnabled) {
                VStack(alignment: .leading) {
                    Text("Sync via iCloud")
                        .font(.headline)
                    Text("Keep it local or sync across devices later.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.switch)
            .tint(.accentColor)

            VStack(alignment: .leading, spacing: 8) {
                Label("No third-party servers", systemImage: "shield.checkerboard")
                Label("Toggle anytime in Settings", systemImage: "gearshape")
            }
            .foregroundStyle(.secondary)
            Spacer()
        }
    }
}

private struct SummaryStep: View {
    let currency: String
    let exchangeMode: ExchangeMode
    let syncEnabled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SummaryRow(title: "Base Currency", value: currency)
            SummaryRow(title: "Exchange Mode", value: exchangeMode.title)
            SummaryRow(title: "iCloud Sync", value: syncEnabled ? "Enabled" : "Disabled")
            Text("You're ready to start tracking wallets, budgets, and investments.")
                .foregroundStyle(.secondary)
            Spacer()
        }
    }
}

// MARK: - Shared Types

private enum OnboardingStep: Int, CaseIterable, Identifiable {
    case welcome, currency, exchangeMode, cloudSync, summary

    var id: Int { rawValue }

    var header: String {
        switch self {
        case .welcome: return "Welcome to Ledgerly"
        case .currency: return "Pick a Base Currency"
        case .exchangeMode: return "Exchange Rate Mode"
        case .cloudSync: return "Choose Sync Preferences"
        case .summary: return "You're All Set"
        }
    }

    var subtitle: String {
        switch self {
        case .welcome: return "Offline-first, privacy-respecting finance."
        case .currency: return "We normalize everything using this currency."
        case .exchangeMode: return "Official, parallel, or manual rates—your choice."
        case .cloudSync: return "Keep data local or enable iCloud sync."
        case .summary: return "Confirm and start building wallets."
        }
    }

    var progress: Double {
        let maxIndex = Double(OnboardingStep.allCases.count - 1)
        guard maxIndex > 0 else { return 1 }
        return Double(rawValue) / maxIndex
    }

    var previous: OnboardingStep? {
        guard let index = OnboardingStep.allCases.firstIndex(of: self), index > 0 else { return nil }
        return OnboardingStep.allCases[index - 1]
    }

    var next: OnboardingStep? {
        guard let index = OnboardingStep.allCases.firstIndex(of: self), index < OnboardingStep.allCases.count - 1 else { return nil }
        return OnboardingStep.allCases[index + 1]
    }
}

private struct SummaryRow: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    OnboardingView(
        initialSnapshot: AppSettingsSnapshot(
            baseCurrencyCode: "USD",
            exchangeMode: .official,
            cloudSyncEnabled: false,
            hasCompletedOnboarding: false,
            priceRefreshIntervalMinutes: 30
        )
    )
    .environmentObject(AppSettingsStore(persistence: PersistenceController.preview))
}
