import SwiftUI

/// Multi-step onboarding that matches the PRD: welcome → currency → exchange mode → summary.
struct OnboardingView: View {
    @EnvironmentObject private var appSettingsStore: AppSettingsStore

    @State private var currentStep: OnboardingStep = .welcome
    @State private var selectedCurrency: String
    @State private var selectedExchangeMode: ExchangeMode
    @State private var exchangeRateAPIKey: String
    @State private var isSaving = false
    @State private var syncErrorMessage: String?

    init(initialSnapshot: AppSettingsSnapshot) {
        _selectedCurrency = State(initialValue: initialSnapshot.baseCurrencyCode)
        _selectedExchangeMode = State(initialValue: initialSnapshot.exchangeMode)
        _exchangeRateAPIKey = State(initialValue: initialSnapshot.exchangeRateAPIKey ?? "")
    }

    var body: some View {
        VStack(spacing: 28) {
            OnboardingHeader(step: currentStep)
            StepContent(
                step: currentStep,
                selectedCurrency: $selectedCurrency,
                selectedExchangeMode: $selectedExchangeMode,
                exchangeRateAPIKey: $exchangeRateAPIKey
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            HStack {
                if currentStep != .welcome {
                    Button("Back", action: goBack)
                        .buttonStyle(.borderless)
                }
                Spacer()
                Button(action: advance) {
                    if currentStep == .summary {
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
        .animation(.easeInOut, value: currentStep)
        .alert("Setup Note", isPresented: Binding(
            get: { syncErrorMessage != nil },
            set: { if !$0 { syncErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { syncErrorMessage = nil }
        } message: {
            Text(syncErrorMessage ?? "")
        }
    }

    private var canContinue: Bool {
        switch currentStep {
        case .welcome, .summary:
            return true
        case .currency:
            return !selectedCurrency.trimmingCharacters(in: .whitespaces).isEmpty
        case .exchangeMode:
            return selectedExchangeMode != .official || normalizedAPIKey(exchangeRateAPIKey) != nil
        }
    }

    private func goBack() {
        guard let previous = currentStep.previous else { return }
        currentStep = previous
    }

    private func advance() {
        guard !isSaving else { return }
        if currentStep == .summary {
            completeOnboarding()
            return
        }
        guard let next = currentStep.next else { return }
        currentStep = next
    }

    private func completeOnboarding() {
        isSaving = true
        Task { @MainActor in
            appSettingsStore.updateExchangeMode(selectedExchangeMode)
            appSettingsStore.updateExchangeRateAPIKey(exchangeRateAPIKey)

            if selectedExchangeMode == .official {
                do {
                    _ = try await appSettingsStore.syncOfficialExchangeRates(
                        apiKeyOverride: exchangeRateAPIKey,
                        baseCurrencyOverride: selectedCurrency,
                        ignoreMode: true
                    )
                } catch {
                    appSettingsStore.updateBaseCurrency(code: selectedCurrency)
                    syncErrorMessage = error.localizedDescription
                }
            } else {
                appSettingsStore.updateBaseCurrency(code: selectedCurrency)
            }

            appSettingsStore.markOnboardingComplete()
            isSaving = false
        }
    }

    private func normalizedAPIKey(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

// MARK: Header

private struct OnboardingHeader: View {
    let step: OnboardingStep

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(step.header)
                .font(.largeTitle.bold())
            Text(step.subtitle)
                .foregroundStyle(.secondary)
            ProgressView(value: step.progress, total: 1)
                .tint(.accentColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: Step Content

private struct StepContent: View {
    let step: OnboardingStep

    @Binding var selectedCurrency: String
    @Binding var selectedExchangeMode: ExchangeMode
    @Binding var exchangeRateAPIKey: String

    var body: some View {
        switch step {
        case .welcome:
            WelcomeStepView()
        case .currency:
            CurrencyPickerView(
                selectedCode: $selectedCurrency,
                infoText: "Choose a base currency for reports. Wallets can still hold any currency."
            )
        case .exchangeMode:
            ExchangeModeStepView(
                selectedMode: $selectedExchangeMode,
                exchangeRateAPIKey: $exchangeRateAPIKey
            )
        case .summary:
            SummaryStepView(
                currency: selectedCurrency,
                exchangeMode: selectedExchangeMode
            )
        }
    }
}

private struct WelcomeStepView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Ledgerly keeps everything on-device by default. You control when and how data syncs.")
            Label("Offline-first, no ads, no trackers.", systemImage: "lock.shield")
            Label("Track salary, cash, bank, and freelance wallets.", systemImage: "wallet.pass")
            Label("Budgeting, investments, and net worth in one place.", systemImage: "chart.line.uptrend.xyaxis")
            Spacer()
        }
    }
}

private struct ExchangeModeStepView: View {
    @Binding var selectedMode: ExchangeMode
    @Binding var exchangeRateAPIKey: String
    private let modes = ExchangeMode.allCases

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Pick how exchange rates behave globally.")
                .foregroundStyle(.secondary)
            ForEach(modes, id: \.self) { mode in
                ExchangeModeCard(mode: mode, isSelected: selectedMode == mode) {
                    selectedMode = mode
                }
            }
            if selectedMode == .official {
                VStack(alignment: .leading, spacing: 8) {
                    SecureField("ExchangeRate-API Key", text: $exchangeRateAPIKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .privacySensitive()
                        .textFieldStyle(.roundedBorder)
                    Text("Official mode requires your ExchangeRate-API key to sync live rates.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }
}

private struct ExchangeModeCard: View {
    let mode: ExchangeMode
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(mode.title)
                        .font(.headline)
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.accentColor)
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
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct SummaryStepView: View {
    let currency: String
    let exchangeMode: ExchangeMode

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SummaryRow(title: "Base Currency", value: currency)
            SummaryRow(title: "Exchange Mode", value: exchangeMode.title)
            Text("You're ready to add wallets, budgets, and investments.")
                .foregroundStyle(.secondary)
            Spacer()
        }
    }
}

// MARK: Supporting Types

private enum OnboardingStep: Int, CaseIterable {
    case welcome, currency, exchangeMode, summary

    var header: String {
        switch self {
        case .welcome: return "Welcome to Ledgerly"
        case .currency: return "Pick a Base Currency"
        case .exchangeMode: return "Exchange Rate Mode"
        case .summary: return "You're All Set"
        }
    }

    var subtitle: String {
        switch self {
        case .welcome: return "Offline-first, privacy-respecting finance."
        case .currency: return "We normalize dashboards using this currency."
        case .exchangeMode: return "Choose Official (API-powered) or Manual rates."
        case .summary: return "Confirm and start tracking."
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
            priceRefreshIntervalMinutes: 30,
            notificationsEnabled: true,
            dashboardWidgets: DashboardWidget.defaultOrder,
            exchangeRates: [:],
            exchangeRateAPIKey: nil,
            stockApiKey: nil,
            cryptoApiKey: nil
        )
    )
    .environmentObject(AppSettingsStore(persistence: PersistenceController.preview))
}
