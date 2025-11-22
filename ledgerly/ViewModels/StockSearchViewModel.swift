import Combine
import Foundation
import Combine

@MainActor
final class StockSearchViewModel: ObservableObject {
    @Published private(set) var results: [MassiveClient.TickerSearchResult] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var errorMessage: String?

    private let client: MassiveClient
    private var searchTask: Task<Void, Never>?

    init(client: MassiveClient = MassiveClient()) {
        self.client = client
    }

    func updateQuery(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2 else {
            searchTask?.cancel()
            results = []
            isLoading = false
            errorMessage = nil
            return
        }

        searchTask?.cancel()
        isLoading = true
        errorMessage = nil
        searchTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard let self, !Task.isCancelled else { return }
            do {
                let fetched = try await self.client.searchTickers(matching: trimmed)
                try Task.checkCancellation()
                await MainActor.run {
                    self.results = fetched
                    self.isLoading = false
                    self.errorMessage = nil
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.results = []
                    self.isLoading = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func clear() {
        searchTask?.cancel()
        results = []
        isLoading = false
        errorMessage = nil
    }
}
