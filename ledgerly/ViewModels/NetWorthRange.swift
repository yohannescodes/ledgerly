import Foundation

enum NetWorthRange: String, CaseIterable, Identifiable {
    case threeMonths
    case sixMonths
    case oneYear
    case all

    var id: String { rawValue }

    var title: String {
        switch self {
        case .threeMonths: return "3M"
        case .sixMonths: return "6M"
        case .oneYear: return "1Y"
        case .all: return "All"
        }
    }

    private var monthsBack: Int? {
        switch self {
        case .threeMonths: return 3
        case .sixMonths: return 6
        case .oneYear: return 12
        case .all: return nil
        }
    }

    func filter(snapshots: [NetWorthSnapshotModel]) -> [NetWorthSnapshotModel] {
        guard let monthsBack else { return snapshots }
        let calendar = Calendar.current
        guard let threshold = calendar.date(byAdding: .month, value: -monthsBack, to: Date()) else { return snapshots }
        return snapshots.filter { $0.timestamp >= threshold }
    }
}
