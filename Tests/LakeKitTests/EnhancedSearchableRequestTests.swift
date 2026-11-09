import XCTest
@testable import LakeKit

private actor EnhancedSearchDebounceGate {
    let entered: XCTestExpectation
    private var isReleased = false
    private var continuation: CheckedContinuation<Void, Never>?

    init(entered: XCTestExpectation) { self.entered = entered }

    func wait() async {
        entered.fulfill()
        guard !isReleased else { return }
        // Deliberately noncooperative, so cancellation must be checked after
        // debounce returns rather than assumed from a timer implementation.
        await withCheckedContinuation { continuation = $0 }
    }

    func release() {
        isReleased = true
        continuation?.resume()
        continuation = nil
    }
}

@MainActor
private final class EnhancedSearchOutputProbe {
    private(set) var values: [String] = []
    func append(_ value: String) { values.append(value) }
}

final class EnhancedSearchableRequestTests: XCTestCase {
    @MainActor
    func testReplacementRejectsOldDebounceEvenWhenTheQueryIsRepeated() async {
        let coordinator = EnhancedSearchRequestCoordinator()
        defer { coordinator.cancel() }
        let entered = expectation(description: "old debounce entered")
        let gate = EnhancedSearchDebounceGate(entered: entered)
        let output = EnhancedSearchOutputProbe()
        let old = coordinator.schedule(searchText: "same", waitForDebounce: { await gate.wait() },
            admitsRequest: { true }, searchAction: { await output.append("old-" + $0) })
        await fulfillment(of: [entered], timeout: 2)
        let current = coordinator.schedule(searchText: "same", waitForDebounce: {},
            admitsRequest: { true }, searchAction: { await output.append("new-" + $0) })
        await current.value
        await gate.release()
        await old.value
        XCTAssertEqual(output.values, ["new-same"])
    }

    @MainActor
    func testHiddenOrReplacedPresentationCannotStartAnAdmittedSearch() async {
        let coordinator = EnhancedSearchRequestCoordinator()
        defer { coordinator.cancel() }
        let entered = expectation(description: "debounce entered")
        let gate = EnhancedSearchDebounceGate(entered: entered)
        let output = EnhancedSearchOutputProbe()
        var presentationIsCurrent = true
        let operation = coordinator.schedule(searchText: "query", waitForDebounce: { await gate.wait() },
            admitsRequest: { presentationIsCurrent }, searchAction: { await output.append($0) })
        await fulfillment(of: [entered], timeout: 2)
        presentationIsCurrent = false
        await gate.release()
        await operation.value
        XCTAssertTrue(output.values.isEmpty)
    }

    @MainActor
    func testCancellationReachesAnAlreadyStartedSearchAction() async {
        let coordinator = EnhancedSearchRequestCoordinator()
        defer { coordinator.cancel() }
        let entered = expectation(description: "search action entered")
        let gate = EnhancedSearchDebounceGate(entered: entered)
        let output = EnhancedSearchOutputProbe()
        let operation = coordinator.schedule(searchText: "query", waitForDebounce: {},
            admitsRequest: { true }, searchAction: { query in
                await gate.wait()
                try Task.checkCancellation()
                await output.append(query)
            })
        await fulfillment(of: [entered], timeout: 2)
        coordinator.cancel()
        XCTAssertFalse(Task.isCancelled)
        await gate.release()
        await operation.value
        XCTAssertTrue(output.values.isEmpty)
    }
}
