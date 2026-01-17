import SwiftUI
import CoreData

struct CategoryFormView: View {
    let onSave: (CategoryModel) -> Void
    private let category: Category?
    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var type: String

    init(category: Category? = nil, onSave: @escaping (CategoryModel) -> Void) {
        self.category = category
        self.onSave = onSave
        _name = State(initialValue: category?.name ?? "")
        _type = State(initialValue: category?.type ?? "expense")
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                Picker("Type", selection: $type) {
                    Text("Expense").tag("expense")
                    Text("Income").tag("income")
                }
                .pickerStyle(.segmented)
            }
            .navigationTitle(category == nil ? "New Category" : "Edit Category")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: dismiss.callAsFunction)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        let savedCategory: Category
        if let category {
            category.name = trimmedName
            category.type = type
            category.updatedAt = Date()
            savedCategory = category
        } else {
            let sortOrder = nextSortOrder()
            savedCategory = Category.create(in: context, name: trimmedName, type: type, sortOrder: sortOrder)
        }
        try? context.save()
        onSave(CategoryModel(managedObject: savedCategory))
        dismiss()
    }

    private func nextSortOrder() -> Int16 {
        let request: NSFetchRequest<Category> = Category.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Category.sortOrder, ascending: false)]
        request.fetchLimit = 1
        let highest = (try? context.fetch(request))?.first?.sortOrder ?? Int16(-1)
        return highest + 1
    }
}
