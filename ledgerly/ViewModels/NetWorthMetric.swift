import SwiftUI

enum NetWorthMetric: String, CaseIterable, Identifiable {
    case total
    case core
    case tangible
    case volatile

    var id: String { rawValue }

    var title: String {
        switch self {
        case .total: return "Total"
        case .core: return "Core"
        case .tangible: return "Tangible"
        case .volatile: return "Volatile"
        }
    }

    var color: Color {
        switch self {
        case .total: return .blue
        case .core: return .green
        case .tangible: return .orange
        case .volatile: return .purple
        }
    }

    static var defaultVisible: Set<NetWorthMetric> {
        [.total, .core, .tangible]
    }

    func value(for snapshot: NetWorthSnapshotModel) -> Decimal {
        switch self {
        case .total:
            return snapshot.totalAssets - snapshot.totalLiabilities
        case .core:
            return snapshot.coreNetWorth
        case .tangible:
            return snapshot.tangibleNetWorth
        case .volatile:
            return snapshot.volatileAssets
        }
    }
}
