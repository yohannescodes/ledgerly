import CoreData
import Foundation

struct CategoryModel: Identifiable, Hashable {
    let id: NSManagedObjectID
    let identifier: String
    let name: String
    let type: String
    let colorHex: String?
    let iconName: String?
    let sortOrder: Int16
}

extension CategoryModel {
    init(managedObject: Category) {
        id = managedObject.objectID
        identifier = managedObject.identifier ?? UUID().uuidString
        name = managedObject.name ?? "Category"
        type = managedObject.type ?? "expense"
        colorHex = managedObject.colorHex
        iconName = managedObject.iconName
        sortOrder = managedObject.sortOrder
    }
}

extension Category {
    static func fetchRequestAll() -> NSFetchRequest<Category> {
        let request: NSFetchRequest<Category> = Category.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Category.sortOrder, ascending: true)]
        return request
    }

    static func create(
        in context: NSManagedObjectContext,
        identifier: String = UUID().uuidString,
        name: String,
        type: String,
        colorHex: String? = nil,
        iconName: String? = nil,
        sortOrder: Int16 = 0
    ) -> Category {
        let category = Category(context: context)
        category.identifier = identifier
        category.name = name
        category.type = type
        category.colorHex = colorHex
        category.iconName = iconName
        category.sortOrder = sortOrder
        category.createdAt = Date()
        category.updatedAt = Date()
        return category
    }
}

enum CategoryDefaults {
    struct Definition {
        let name: String
        let type: String
        let colorHex: String?
        let iconName: String?
    }

    static let all: [Definition] = [
        .init(name: "Groceries", type: "expense", colorHex: "#FF9F0A", iconName: "cart"),
        .init(name: "Housing", type: "expense", colorHex: "#FF3B30", iconName: "house"),
        .init(name: "Transport", type: "expense", colorHex: "#0A84FF", iconName: "car"),
        .init(name: "Utilities", type: "expense", colorHex: "#5AC8FA", iconName: "bolt"),
        .init(name: "Health", type: "expense", colorHex: "#FF2D55", iconName: "cross"),
        .init(name: "Entertainment", type: "expense", colorHex: "#AF52DE", iconName: "gamecontroller"),
        .init(name: "Education", type: "expense", colorHex: "#FFD60A", iconName: "book"),
        .init(name: "Dining", type: "expense", colorHex: "#FF9500", iconName: "fork.knife"),
        .init(name: "Travel", type: "expense", colorHex: "#007AFF", iconName: "airplane"),
        .init(name: "Gifts", type: "expense", colorHex: "#FF375F", iconName: "gift"),
        .init(name: "Fees", type: "expense", colorHex: "#8E8E93", iconName: "percent"),
        .init(name: "Taxes", type: "expense", colorHex: "#FF9500", iconName: "doc.text"),
        .init(name: "Savings", type: "expense", colorHex: "#32D74B", iconName: "banknote"),
        .init(name: "Salary", type: "income", colorHex: "#34C759", iconName: "briefcase"),
        .init(name: "Freelance", type: "income", colorHex: "#30B0C7", iconName: "laptopcomputer"),
        .init(name: "Investments", type: "income", colorHex: "#34C759", iconName: "chart.line.uptrend.xyaxis"),
        .init(name: "Rental", type: "income", colorHex: "#5AC8FA", iconName: "house"),
        .init(name: "Refund", type: "income", colorHex: "#FFCC00", iconName: "arrow.uturn.left"),
        .init(name: "Other", type: "expense", colorHex: "#8E8E93", iconName: "ellipsis")
    ]

    static func ensureDefaults(in context: NSManagedObjectContext) {
        let request: NSFetchRequest<Category> = Category.fetchRequest()
        let count = (try? context.count(for: request)) ?? 0
        guard count == 0 else { return }
        for (index, def) in all.enumerated() {
            let sortOrder = Int16(index)
            _ = Category.create(
                in: context,
                name: def.name,
                type: def.type,
                colorHex: def.colorHex,
                iconName: def.iconName,
                sortOrder: sortOrder
            )
        }
    }
}
