import Foundation

@MainActor
final class EnhancedSearchRequestCoordinator {
    private var generation = 0
    private var task: Task<Void, Never>?

    @discardableResult
    func schedule(
        searchText: String,
        waitForDebounce: @escaping @Sendable () async throws -> Void = {
            try await Task.sleep(nanoseconds: 180_000_000)
        },
        admitsRequest: @escaping @MainActor () -> Bool,
        searchAction: @escaping @Sendable (String) async throws -> Void
    ) -> Task<Void, Never> {
        generation &+= 1
        let owner = generation
        let predecessor = task
        let operation = Task { @MainActor [weak self] in
            defer {
                if self?.generation == owner { self?.task = nil }
            }
            do {
                try await waitForDebounce()
                try Task.checkCancellation()
                guard self?.generation == owner, admitsRequest(), self?.generation == owner else { return }
                // An already-started search owns its own result publication.
                try await searchAction(searchText)
            } catch { }
        }
        task = operation
        predecessor?.cancel()
        return operation
    }

    @discardableResult
    func cancel() -> Bool {
        generation &+= 1
        let retired = task
        task = nil
        retired?.cancel()
        return retired != nil
    }
}
