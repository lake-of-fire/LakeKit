import XCTest
@testable import LakeKit

final class LocationBarProgressHideTests: XCTestCase {
    @MainActor
    func testCanceledCompletionCannotHideSuccessorProgress() async throws {
        var visible = true
        var progress = 1.0
        let sleeper = SuspendedSleep()
        let oldTask = Task { @MainActor in
            await LocationBarProgressHide.run(after: 0.35, sleep: sleeper.sleep) {
                visible = false
                progress = 0
            }
        }
        defer {
            oldTask.cancel()
            sleeper.resume()
        }
        try await sleeper.waitUntilSleeping()
        oldTask.cancel()
        visible = true
        progress = 0.25
        sleeper.resume()
        await oldTask.value
        XCTAssertTrue(visible)
        XCTAssertEqual(progress, 0.25)
    }

    @MainActor
    func testUncancelledCompletionStillHidesAndResetsProgress() async {
        var visible = true
        var progress = 1.0
        var requestedDelay: UInt64?
        await LocationBarProgressHide.run(after: 0.35, sleep: { requestedDelay = $0 }) {
            visible = false
            progress = 0
        }
        XCTAssertEqual(requestedDelay, 350_000_000)
        XCTAssertFalse(visible)
        XCTAssertEqual(progress, 0)
    }

    @MainActor
    func testThrowingSleepDoesNotRunCompletion() async {
        var completed = false
        await LocationBarProgressHide.run(after: 0.35, sleep: { _ in
            throw CancellationError()
        }) { completed = true }
        XCTAssertFalse(completed)
    }

    @MainActor
    func testAlreadyCanceledTaskDoesNotSleepOrComplete() async {
        var slept = false
        var completed = false
        let task = Task { @MainActor in
            await LocationBarProgressHide.run(after: 0.35, sleep: { _ in slept = true }) {
                completed = true
            }
        }
        // The child cannot begin on this actor until the following suspension.
        task.cancel()
        await task.value
        XCTAssertFalse(slept)
        XCTAssertFalse(completed)
    }
}

@MainActor
private final class SuspendedSleep {
    private enum WaitError: Error { case didNotStart }

    private var continuation: CheckedContinuation<Void, Never>?
    private let started = XCTestExpectation(description: "progress hide sleep started")

    func sleep(_ nanoseconds: UInt64) async throws {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            started.fulfill()
        }
    }

    func waitUntilSleeping() async throws {
        let status = await XCTWaiter.fulfillment(of: [started], timeout: 5)
        guard status == .completed, continuation != nil else { throw WaitError.didNotStart }
    }

    func resume() {
        continuation?.resume()
        continuation = nil
    }
}
