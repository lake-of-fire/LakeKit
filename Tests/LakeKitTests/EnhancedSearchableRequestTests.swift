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
#if os(macOS)
    @MainActor
    func testNativeSearchEditsCoalesceThenContinueFromAcknowledgedText() async throws {
        let writeback = EnhancedSearchFieldWriteback()
        var input = EnhancedSearchFieldWriteback.Input(text: "", ownerRevision: 1)
        var committed: [String] = []
        let commit: @MainActor (String) -> Void = { value in
            committed.append(value)
            input = .init(text: value, ownerRevision: input.ownerRevision)
        }

        let first = try XCTUnwrap(writeback.receive("a", currentInput: { input }, commit: commit))
        _ = writeback.receive("ab", currentInput: { input }, commit: commit)
        XCTAssertTrue(writeback.hasPendingEdit(from: input))
        await first.value
        XCTAssertEqual(committed, ["ab"])
        XCTAssertFalse(writeback.hasPendingEdit(from: input))

        // Model acknowledgement leaves the native owner unchanged. The next
        // keystroke starts from the text that was actually committed.
        let next = try XCTUnwrap(writeback.receive("abc", currentInput: { input }, commit: commit))
        await next.value
        XCTAssertEqual(committed, ["ab", "abc"])
    }

    @MainActor
    func testNativeSearchEditCannotOverwriteAnExternalClear() async throws {
        let writeback = EnhancedSearchFieldWriteback()
        var input = EnhancedSearchFieldWriteback.Input(text: "current", ownerRevision: 1)
        var committed: [String] = []
        let edit = try XCTUnwrap(writeback.receive("current edit", currentInput: { input }) {
            committed.append($0)
        })

        input = .init(text: "", ownerRevision: 1)
        XCTAssertFalse(writeback.hasPendingEdit(from: input))
        await edit.value
        XCTAssertEqual(input.text, "")
        XCTAssertTrue(committed.isEmpty)
    }

    @MainActor
    func testNativeSearchEditCannotCrossAnExplicitClearOrReappearance() async throws {
        let writeback = EnhancedSearchFieldWriteback()
        var input: EnhancedSearchFieldWriteback.Input? = .init(text: "", ownerRevision: 1)
        var committed: [String] = []
        let initialEdit = try XCTUnwrap(writeback.receive("old", currentInput: { input }) {
            committed.append($0)
        })

        // Escape rejects pending native input even if the bound text was
        // already empty. The field is also inadmissible while it is hidden.
        input = nil
        XCTAssertNil(writeback.receive("hidden edit", currentInput: { input }) { committed.append($0) })
        input = .init(text: "", ownerRevision: 2)
        await initialEdit.value
        XCTAssertTrue(committed.isEmpty)

        let newEdit = try XCTUnwrap(writeback.receive("new", currentInput: { input }) {
            committed.append($0)
        })
        await newEdit.value
        XCTAssertEqual(committed, ["new"])
    }

    @MainActor
    func testNativeSearchEditCannotCrossSameTextAutosaveOwnerReplacement() async throws {
        let writeback = EnhancedSearchFieldWriteback()
        var input = EnhancedSearchFieldWriteback.Input(text: "", ownerRevision: 1, autosaveName: "sentences")
        var committed: [String] = []
        let old = try XCTUnwrap(writeback.receive("old", currentInput: { input }) { committed.append($0) })

        // A native update can refresh its parent before SwiftUI delivers the
        // modifier's onChange. Both owners still have the same text and epoch.
        input = .init(text: "", ownerRevision: 1, autosaveName: "flashcards")
        XCTAssertFalse(writeback.hasPendingEdit(from: input))
        await old.value
        XCTAssertTrue(committed.isEmpty)

        let current = try XCTUnwrap(writeback.receive("new", currentInput: { input }) { committed.append($0) })
        await current.value
        XCTAssertEqual(committed, ["new"])
    }

    @MainActor
    func testNativeSearchEditCannotCrossUnobservedPresentationChange() async throws {
        let writeback = EnhancedSearchFieldWriteback()
        var input = EnhancedSearchFieldWriteback.Input(text: "", ownerRevision: 1, isPresented: true)
        var committed: [String] = []
        let old = try XCTUnwrap(writeback.receive("old", currentInput: { input }) { committed.append($0) })

        input = .init(text: "", ownerRevision: 1, isPresented: false)
        await old.value
        XCTAssertTrue(committed.isEmpty)

        let current = try XCTUnwrap(writeback.receive("new", currentInput: { input }) { committed.append($0) })
        await current.value
        XCTAssertEqual(committed, ["new"], "A mounted Mac field may accept input when isPresented is false")
    }

    @MainActor
    func testReentrantInputReadCannotReplaceNewerNativeEdit() async throws {
        let writeback = EnhancedSearchFieldWriteback()
        let input = EnhancedSearchFieldWriteback.Input(text: "", ownerRevision: 1)
        var committed: [String] = []
        var replacement: Task<Void, Never>?
        let retired = writeback.receive("old", currentInput: {
            replacement = writeback.receive("new", currentInput: { input }) { committed.append($0) }
            return input
        }) { committed.append($0) }

        XCTAssertNil(retired)
        let current = try XCTUnwrap(replacement)
        await current.value
        XCTAssertEqual(committed, ["new"])
    }

    @MainActor
    func testReentrantInputReadCanCancelOrReplaceNativeDelivery() async throws {
        for replacesEdit in [false, true] {
            let writeback = EnhancedSearchFieldWriteback()
            let input = EnhancedSearchFieldWriteback.Input(text: "", ownerRevision: 1)
            var committed: [String] = []
            var shouldReenter = false
            var replacement: Task<Void, Never>?
            let retired = try XCTUnwrap(writeback.receive("old", currentInput: {
                if shouldReenter {
                    if replacesEdit {
                        replacement = writeback.receive("new", currentInput: { input }) { committed.append($0) }
                    } else {
                        writeback.cancel()
                    }
                }
                return input
            }) { committed.append($0) })
            shouldReenter = true

            await retired.value
            if replacesEdit {
                let current = try XCTUnwrap(replacement)
                await current.value
                XCTAssertEqual(committed, ["new"])
            } else {
                XCTAssertTrue(committed.isEmpty)
            }
        }
    }

    @MainActor
    func testDismantledNativeSearchCannotConsumeReplacementEdit() async throws {
        let writeback = EnhancedSearchFieldWriteback()
        let input = EnhancedSearchFieldWriteback.Input(text: "", ownerRevision: 1)
        var committed: [String] = []
        let retired = try XCTUnwrap(writeback.receive("retired", currentInput: { input }) {
            committed.append($0)
        })
        writeback.cancel()
        let replacement = try XCTUnwrap(writeback.receive("replacement", currentInput: { input }) {
            committed.append($0)
        })
        await retired.value
        await replacement.value

        XCTAssertEqual(committed, ["replacement"])
    }
#endif

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

    @MainActor
    func testRetiredDebounceCannotDiscardAnUnfinishedReplacement() async {
        let coordinator = EnhancedSearchRequestCoordinator()
        let oldEntered = expectation(description: "old debounce entered")
        let newEntered = expectation(description: "replacement debounce entered")
        let oldGate = EnhancedSearchDebounceGate(entered: oldEntered)
        let newGate = EnhancedSearchDebounceGate(entered: newEntered)
        let output = EnhancedSearchOutputProbe()
        let old = coordinator.schedule(searchText: "old", waitForDebounce: { await oldGate.wait() },
            admitsRequest: { true }, searchAction: { await output.append($0) })
        await fulfillment(of: [oldEntered], timeout: 2)
        let replacement = coordinator.schedule(searchText: "new", waitForDebounce: { await newGate.wait() },
            admitsRequest: { true }, searchAction: { await output.append($0) })
        await fulfillment(of: [newEntered], timeout: 2)
        await oldGate.release()
        await old.value

        XCTAssertTrue(coordinator.cancel(), "The departing host still owns unfinished work to resume")
        await newGate.release()
        await replacement.value
        XCTAssertTrue(output.values.isEmpty)
        XCTAssertFalse(coordinator.cancel(), "A settled request does not need to resume")
    }
}
