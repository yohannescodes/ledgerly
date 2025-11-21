import Foundation
import SwiftUI
import Combine

@MainActor
final class TransactionsViewModel: ObservableObject {
    @Published var filter = TransactionFilter()
    @Published private(set) var sections: [TransactionSection] = []

    private let store: TransactionsStore

    init(store: TransactionsStore) {
        self.store = store
        refresh()
    }

    func refresh() {
        sections = store.fetchSections(filter: filter)
    }

    func updateSegment(_ segment: TransactionFilter.Segment) {
        filter.segment = segment
        refresh()
    }
}
