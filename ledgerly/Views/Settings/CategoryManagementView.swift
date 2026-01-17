import CoreData
import SwiftUI

struct CategoryManagementView: View {
    @Environment(\.managedObjectContext) private var context
    @FetchRequest(fetchRequest: Category.fetchRequestAll()) private var categories: FetchedResults<Category>
    @State private var showingAddForm = false
    @State private var categoryToEdit: Category?

    var body: some View {
        List {
            if categories.isEmpty {
                Section {
                    ContentUnavailableView(
                        label: {
                            Label("No categories yet", systemImage: "tag")
                        },
                        description: {
                            Text("Create categories to organize transactions, budgets, and goals.")
                        },
                        actions: {
                            Button(action: { showingAddForm = true }) {
                                Label("Add Category", systemImage: "plus")
                            }
                        }
                    )
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            } else {
                Section {
                    ForEach(categories) { category in
                        CategoryRow(category: category)
                            .contentShape(Rectangle())
                            .onTapGesture { categoryToEdit = category }
                    }
                    .onMove(perform: move)
                    .onDelete(perform: delete)
                }
            }
        }
        .navigationTitle("Categories")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                EditButton()
            }
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showingAddForm = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddForm) {
            CategoryFormView { _ in }
        }
        .sheet(item: $categoryToEdit) { category in
            CategoryFormView(category: category) { _ in }
        }
    }

    private func move(from offsets: IndexSet, to destination: Int) {
        var revised = categories.map { $0 }
        revised.move(fromOffsets: offsets, toOffset: destination)
        applySortOrder(revised)
        saveContext()
    }

    private func delete(at offsets: IndexSet) {
        var revised = categories.map { $0 }
        let toDelete = offsets.map { revised[$0] }
        revised.remove(atOffsets: offsets)
        applySortOrder(revised)
        toDelete.forEach(context.delete)
        saveContext()
    }

    private func applySortOrder(_ categories: [Category]) {
        for (index, category) in categories.enumerated() {
            category.sortOrder = Int16(index)
        }
    }

    private func saveContext() {
        try? context.save()
    }
}

private struct CategoryRow: View {
    let category: Category

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                if let iconName {
                    Image(systemName: iconName)
                        .foregroundStyle(color)
                } else {
                    Text(initial)
                        .font(.caption.bold())
                        .foregroundStyle(color)
                }
            }
            .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.headline)
                Text(typeLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }

    private var name: String {
        category.name ?? "Category"
    }

    private var typeLabel: String {
        (category.type ?? "expense").lowercased() == "income" ? "Income" : "Expense"
    }

    private var color: Color {
        Color(hex: category.colorHex ?? "") ?? Color.accentColor
    }

    private var iconName: String? {
        let icon = category.iconName ?? ""
        return icon.isEmpty ? nil : icon
    }

    private var initial: String {
        String(name.prefix(1)).uppercased()
    }
}

#Preview {
    NavigationStack {
        CategoryManagementView()
    }
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
