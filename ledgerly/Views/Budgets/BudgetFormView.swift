import SwiftUI
import CoreData

struct BudgetFormInput {
    var categoryID: NSManagedObjectID?
    var limitAmount: Decimal = .zero
    var currencyCode: String = Locale.current.currency?.identifier ?? "USD"
    var month: Int = Calendar.current.component(.month, from: Date())
    var year: Int = Calendar.current.component(.year, from: Date())
    var existingBudgetID: NSManagedObjectID?
}

struct BudgetFormView: View {
    let onSave: (BudgetFormInput) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var context
    var existingBudget: MonthlyBudgetModel?
    @State private var input = BudgetFormInput()

    init(existingBudget: MonthlyBudgetModel? = nil, onSave: @escaping (BudgetFormInput) -> Void) {
        self.existingBudget = existingBudget
        self.onSave = onSave
        if let budget = existingBudget {
            _input = State(initialValue: BudgetFormInput(categoryID: budget.categoryID, limitAmount: budget.limitAmount, currencyCode: budget.currencyCode, month: budget.month, year: budget.year, existingBudgetID: budget.id))
        }
    }
    @FetchRequest(sortDescriptors: [SortDescriptor(\.name, order: .forward)])
    private var categories: FetchedResults<Category>

    var body: some View {
        NavigationStack {
            Form {
                Section("Category") {
                    Picker("Category", selection: $input.categoryID) {
                        Text("Select").tag(Optional<NSManagedObjectID>(nil))
                        ForEach(categories) { category in
                            Text(category.name ?? "Category")
                                .tag(Optional(category.objectID))
                        }
                    }
                }
                Section("Limit") {
                    DecimalTextField(title: "Amount", value: $input.limitAmount)
                    Stepper("Month: \(input.month)", value: $input.month, in: 1...12)
                    Stepper("Year: \(input.year)", value: $input.year, in: 2020...2100)
                }
            }
            .navigationTitle("New Budget")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: dismiss.callAsFunction) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(input.limitAmount <= 0)
                }
            }
        }
    }

    private func save() {
        onSave(input)
        dismiss()
    }
}
