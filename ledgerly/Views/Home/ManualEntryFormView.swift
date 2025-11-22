import SwiftUI

struct ManualEntryFormView: View {
    let title: String
    let onSave: (ManualEntryInput) -> Void
    let onDelete: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var input: ManualEntryInput

    init(title: String, entry: ManualEntryInput = ManualEntryInput(), onSave: @escaping (ManualEntryInput) -> Void, onDelete: (() -> Void)? = nil) {
        self.title = title
        self.onSave = onSave
        self.onDelete = onDelete
        _input = State(initialValue: entry)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Name", text: $input.name)
                    DecimalTextField(title: "Amount", value: $input.amount)
                    NavigationLink {
                        CurrencyPickerView(selectedCode: $input.currencyCode)
                    } label: {
                        HStack {
                            Text("Currency")
                            Spacer()
                            Text(input.currencyCode)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                if let onDelete {
                    Section {
                        Button(role: .destructive) {
                            onDelete()
                            dismiss()
                        } label: {
                            Text("Delete Entry")
                        }
                    }
                }
            }
            .navigationTitle(title)
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

    private var canSave: Bool {
        !input.name.isEmpty && input.amount > 0
    }

    private func save() {
        onSave(input)
        dismiss()
    }
}
