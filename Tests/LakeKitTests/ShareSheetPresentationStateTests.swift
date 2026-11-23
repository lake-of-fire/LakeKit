import Foundation
import XCTest
@testable import LakeKit

final class ShareSheetPresentationStateTests: XCTestCase {
    func testNilRequestDoesNotPresent() {
        var state = ShareSheetPresentationState()
        XCTAssertEqual(state.update(requestID: nil, hostIsReady: true), .none)
    }
    func testInitialRequestWaitsForAttachment() throws {
        var state = ShareSheetPresentationState()
        let id = UUID()
        XCTAssertEqual(state.update(requestID: id, hostIsReady: false), .none)
        let token = try presentation(&state, id)
        XCTAssertEqual(token.requestID, id)
    }
    func testSameRequestIsNotPresentedTwice() throws {
        var state = ShareSheetPresentationState()
        let id = UUID()
        _ = try presentation(&state, id)
        XCTAssertEqual(state.update(requestID: id, hostIsReady: true), .none)
    }
    func testClearingRequestProducesExactlyOneDismissal() throws {
        var state = ShareSheetPresentationState()
        let token = try presentation(&state, UUID())
        XCTAssertEqual(state.update(requestID: nil, hostIsReady: true), .dismiss(token))
        XCTAssertEqual(state.update(requestID: nil, hostIsReady: true), .none)
        XCTAssertTrue(state.didDismiss(token))
        XCTAssertNil(state.current)
    }
    func testReplacementWaitsForOwnedDismissalAndUsesLatestRequest() throws {
        var state = ShareSheetPresentationState()
        let old = try presentation(&state, UUID()), next = UUID(), latest = UUID()
        XCTAssertEqual(state.update(requestID: next, hostIsReady: true), .dismiss(old))
        XCTAssertEqual(state.update(requestID: latest, hostIsReady: true), .none)
        XCTAssertTrue(state.didDismiss(old))
        XCTAssertEqual(try presentation(&state, latest).requestID, latest)
    }
    func testCompletionCannotClearSuccessorBeforeViewUpdate() throws {
        var state = ShareSheetPresentationState()
        let old = try presentation(&state, UUID()), next = UUID()
        XCTAssertFalse(state.completed(old, requestID: next))
        XCTAssertEqual(try presentation(&state, next).requestID, next)
    }
    func testMatchingCompletionClearsOnlyItsOwnRequest() throws {
        var state = ShareSheetPresentationState()
        let id = UUID(), token = try presentation(&state, id)
        XCTAssertTrue(state.completed(token, requestID: id))
        XCTAssertFalse(state.completed(token, requestID: id))
    }
    func testStaleDismissalCannotCloseNewPresentation() throws {
        var state = ShareSheetPresentationState()
        let old = try presentation(&state, UUID())
        _ = state.update(requestID: nil, hostIsReady: true)
        XCTAssertTrue(state.didDismiss(old))
        let id = UUID(), current = try presentation(&state, id)
        XCTAssertFalse(state.didDismiss(old))
        XCTAssertFalse(state.completed(old, requestID: id))
        XCTAssertTrue(state.owns(current, requestID: id))
    }
    func testDetachAndReattachSameRequestUsesNewGeneration() throws {
        var state = ShareSheetPresentationState()
        let id = UUID(), old = try presentation(&state, id)
        XCTAssertEqual(state.update(requestID: id, hostIsReady: false), .dismiss(old))
        XCTAssertTrue(state.didDismiss(old))
        let new = try presentation(&state, id)
        XCTAssertNotEqual(old, new)
        XCTAssertFalse(state.completed(old, requestID: id))
    }
    func testForeignPresentationTokenHasNoAuthority() throws {
        var first = ShareSheetPresentationState(), second = ShareSheetPresentationState()
        let id = UUID(), a = try presentation(&first, id), b = try presentation(&second, id)
        XCTAssertNotEqual(a, b)
        XCTAssertFalse(first.completed(b, requestID: id))
        XCTAssertTrue(first.owns(a, requestID: id))
    }
    func testCompletionDuringProgrammaticDismissalCannotConsumeSuccessor() throws {
        var state = ShareSheetPresentationState()
        let old = try presentation(&state, UUID()), next = UUID()
        _ = state.update(requestID: next, hostIsReady: true)
        XCTAssertFalse(state.completed(old, requestID: old.requestID))
        XCTAssertTrue(state.isDismissing)
        XCTAssertTrue(state.didDismiss(old))
        _ = try presentation(&state, next)
    }
    func testQueuedPresentationIsInvalidOnceBindingChanges() throws {
        var state = ShareSheetPresentationState()
        let token = try presentation(&state, UUID())
        XCTAssertFalse(state.owns(token, requestID: UUID()))
        XCTAssertFalse(state.owns(token, requestID: nil))
    }

    private func presentation(_ state: inout ShareSheetPresentationState,
                              _ id: UUID) throws -> ShareSheetPresentationState.Token {
        guard case .present(let token) = state.update(requestID: id, hostIsReady: true) else {
            XCTFail("Expected a presentation")
            throw TestError.notPresented
        }
        return token
    }
    private enum TestError: Error { case notPresented }
}
