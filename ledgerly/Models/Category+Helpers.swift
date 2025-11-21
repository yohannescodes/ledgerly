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
