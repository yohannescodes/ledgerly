import CoreData
import SwiftUI

struct TransactionDetailView: View {
    let model: TransactionModel
    let onAction: (TransactionDetailAction) -> TransactionModel?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var context
    @EnvironmentObject private var walletsStore: WalletsStore

    @State private var committedModel: TransactionDetailEditor
    @State private var workingModel: TransactionDetailEditor
    @State private var categories: [CategoryModel] = []
    @State private var expandedField: DetailField?
    @State private var showingCurrencyPicker = false
    @State private var zenModeEnabled = false

    init(model: TransactionModel, onAction: @escaping (TransactionDetailAction) -> TransactionModel?) {
        self.model = model
        self.onAction = onAction
        let editor = TransactionDetailEditor(model: model)
        _committedModel = State(initialValue: editor)
        _workingModel = State(initialValue: editor)
    }

    var body: some View {
        Form {
            Section(header: sectionHeader(title: "Summary", subtitle: "Tap to expand and tweak.")) {
                editableRow(title: "Type", value: workingModel.direction.title, field: .direction) {
                    Picker("Direction", selection: binding(for: \TransactionDetailEditor.direction)) {
                        ForEach(TransactionFormInput.Direction.allCases) { direction in
                            Text(direction.title).tag(direction)
                        }
                    }
                    .pickerStyle(.segmented)
                    Text("Direction instantly updates reports and insights.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    actionButtons(for: .direction)
                }

                editableRow(title: "Amount", value: formattedAmount, field: .amount) {
                    DecimalTextField(title: "Amount", value: binding(for: \TransactionDetailEditor.amount))
                    Text("Only saved when you press Save change below.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    actionButtons(for: .amount)
                }

                editableRow(title: "Currency", value: workingModel.currencyCode, field: .currency) {
                    Button(action: { showingCurrencyPicker = true }) {
                        Label("Pick a currency", systemImage: "globe")
                    }
                    .buttonStyle(.bordered)
                    Text("Use the picker to change the reporting currency.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    actionButtons(for: .currency)
                }

                editableRow(title: "Date", value: workingModel.date.formatted(date: .abbreviated, time: .shortened), field: .date) {
                    DatePicker("When it happened", selection: binding(for: \TransactionDetailEditor.date), displayedComponents: [.date, .hourAndMinute])
                    actionButtons(for: .date)
                }
            }

            Section(header: sectionHeader(title: "Wallet & Category", subtitle: "Keep it organized.")) {
                editableRow(title: "Wallet", value: workingModel.walletName, field: .wallet) {
                    Picker("Wallet", selection: binding(for: \TransactionDetailEditor.walletID)) {
                        Text("Select Wallet").tag(Optional<NSManagedObjectID>(nil))
                        ForEach(walletsStore.wallets) { wallet in
                            Text(wallet.name).tag(Optional(wallet.id))
                        }
                    }
                    .onChange(of: workingModel.walletID) { newValue in
                        if let newValue, let wallet = walletsStore.wallets.first(where: { $0.id == newValue }) {
                            workingModel.walletName = wallet.name
                        }
                    }
                    actionButtons(for: .wallet)
                }

                editableRow(title: "Category", value: workingModel.categoryName ?? "Uncategorized", field: .category) {
                    Picker("Category", selection: binding(for: \TransactionDetailEditor.categoryID)) {
                        Text("Uncategorized").tag(Optional<NSManagedObjectID>(nil))
                        ForEach(categories) { category in
                            Text(category.name).tag(Optional(category.id))
                        }
                    }
                    .onChange(of: workingModel.categoryID) { newValue in
                        if let newValue, let category = categories.first(where: { $0.id == newValue }) {
                            workingModel.categoryName = category.name
                        } else {
                            workingModel.categoryName = nil
                        }
                    }
                    actionButtons(for: .category)
                }
            }

            Section("Notes") {
                editableRow(title: "Notes", value: notesSummary, field: .notes) {
                    TextEditor(text: binding(for: \TransactionDetailEditor.notes))
                        .frame(minHeight: 120)
                    actionButtons(for: .notes)
                }
            }
        }
        .navigationTitle("Transaction")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: toggleZenMode) {
                    Label(zenModeEnabled ? "Collapse" : "Zen Edit", systemImage: zenModeEnabled ? "rectangle.compress.vertical" : "wand.and.stars")
                }
                .help("Zen Edit keeps every editor expanded for rapid tweaks.")
            }
            ToolbarItem(placement: .destructiveAction) {
                Button(role: .destructive) {
                    _ = onAction(.delete)
                    dismiss()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .sheet(isPresented: $showingCurrencyPicker) {
            NavigationStack {
                CurrencyPickerView(selectedCode: binding(for: \TransactionDetailEditor.currencyCode)) { _ in
                    showingCurrencyPicker = false
                }
                    .navigationTitle("Currency")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showingCurrencyPicker = false }
                        }
                    }
            }
        }
        .onAppear(perform: loadCategories)
        .onChange(of: model) { updated in
            let editor = TransactionDetailEditor(model: updated)
            committedModel = editor
            workingModel = editor
        }
    }

    private var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = workingModel.currencyCode
        return formatter.string(from: workingModel.amount as NSNumber) ?? "--"
    }

    private var notesSummary: String {
        let trimmed = workingModel.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Add a memory or important detail" : trimmed
    }

    private func binding<Value>(for keyPath: WritableKeyPath<TransactionDetailEditor, Value>) -> Binding<Value> {
        Binding(
            get: { workingModel[keyPath: keyPath] },
            set: { workingModel[keyPath: keyPath] = $0 }
        )
    }

    private func actionButtons(for field: DetailField) -> some View {
        HStack(spacing: 12) {
            Button("Save change") { save(field: field) }
                .buttonStyle(.borderedProminent)
                .disabled(!hasPendingChanges(for: field))
            Button("Reset") { reset(field: field) }
                .buttonStyle(.bordered)
        }
        .padding(.top, 4)
    }

    private func save(field: DetailField) {
        guard hasPendingChanges(for: field) else { return }
        let action: TransactionDetailAction
        switch field {
        case .direction:
            action = .update(.direction(workingModel.direction))
        case .amount:
            action = .update(.amount(workingModel.amount))
        case .currency:
            action = .update(.currency(workingModel.currencyCode))
        case .wallet:
            guard let walletID = workingModel.walletID else { return }
            action = .update(.wallet(walletID))
        case .date:
            action = .update(.date(workingModel.date))
        case .category:
            action = .update(.category(workingModel.categoryID))
        case .notes:
            action = .update(.notes(workingModel.notes))
        }
        if let updated = onAction(action) {
            let editor = TransactionDetailEditor(model: updated)
            committedModel = editor
            workingModel = editor
        }
        if !zenModeEnabled {
            expandedField = nil
        }
    }

    private func reset(field: DetailField) {
        switch field {
        case .direction:
            workingModel.direction = committedModel.direction
        case .amount:
            workingModel.amount = committedModel.amount
        case .currency:
            workingModel.currencyCode = committedModel.currencyCode
        case .wallet:
            workingModel.walletID = committedModel.walletID
            workingModel.walletName = committedModel.walletName
        case .date:
            workingModel.date = committedModel.date
        case .category:
            workingModel.categoryID = committedModel.categoryID
            workingModel.categoryName = committedModel.categoryName
        case .notes:
            workingModel.notes = committedModel.notes
        }
    }

    private func hasPendingChanges(for field: DetailField) -> Bool {
        switch field {
        case .direction:
            return workingModel.direction != committedModel.direction
        case .amount:
            return workingModel.amount != committedModel.amount
        case .currency:
            return workingModel.currencyCode != committedModel.currencyCode
        case .wallet:
            return workingModel.walletID != committedModel.walletID
        case .date:
            return workingModel.date != committedModel.date
        case .category:
            return workingModel.categoryID != committedModel.categoryID
        case .notes:
            return workingModel.notes != committedModel.notes
        }
    }

    private func sectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func editableRow<Content: View>(title: String, value: String, field: DetailField, @ViewBuilder content: @escaping () -> Content) -> some View {
        EditableDetailRow(
            title: title,
            value: value,
            field: field,
            expandedField: $expandedField,
            forceExpanded: zenModeEnabled,
            content: content
        )
    }

    private func loadCategories() {
        let request = Category.fetchRequestAll()
        if let result = try? context.fetch(request) {
            categories = result.map(CategoryModel.init)
        }
    }

    private func toggleZenMode() {
        zenModeEnabled.toggle()
        if !zenModeEnabled {
            expandedField = nil
        }
    }
}

private enum DetailField: Hashable {
    case direction
    case amount
    case currency
    case wallet
    case date
    case category
    case notes
}

private struct EditableDetailRow<Content: View>: View {
    let title: String
    let value: String
    let field: DetailField
    @Binding var expandedField: DetailField?
    let forceExpanded: Bool
    private let builder: () -> Content

    init(
        title: String,
        value: String,
        field: DetailField,
        expandedField: Binding<DetailField?>,
        forceExpanded: Bool,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.value = value
        self.field = field
        _expandedField = expandedField
        self.forceExpanded = forceExpanded
        self.builder = content
    }

    var body: some View {
        DisclosureGroup(isExpanded: binding) {
            VStack(alignment: .leading, spacing: 12) {
                builder()
            }
            .padding(.top, 8)
        } label: {
            HStack {
                Text(title)
                Spacer()
                Text(value)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
    }

    private var binding: Binding<Bool> {
        Binding(
            get: { forceExpanded || expandedField == field },
            set: { newValue in
                guard !forceExpanded else { return }
                expandedField = newValue ? field : nil
            }
        )
    }
}

private struct TransactionDetailEditor {
    var direction: TransactionFormInput.Direction
    var amount: Decimal
    var currencyCode: String
    var walletID: NSManagedObjectID?
    var walletName: String
    var date: Date
    var notes: String
    var categoryID: NSManagedObjectID?
    var categoryName: String?

    init(model: TransactionModel) {
        direction = TransactionFormInput.Direction(rawValue: model.direction) ?? .expense
        amount = model.amount
        currencyCode = model.currencyCode
        walletID = model.walletID
        walletName = model.walletName
        date = model.date
        notes = model.notes ?? ""
        categoryID = model.categoryID
        categoryName = model.category?.name
    }
}
