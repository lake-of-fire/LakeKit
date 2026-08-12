import XCTest
@testable import LakeKit

final class BackgroundWorkerTests: XCTestCase {
    func testStopBeforeStartAndRepeatedStopAreSafe() {
        let worker = BackgroundWorker()
        worker.stop()
        worker.stop()
    }

    func testStartExecutesBlockAndStopIsIdempotent() {
        let executed = expectation(description: "BackgroundWorker block executes")
        let worker = BackgroundWorker()
        worker.start {
            executed.fulfill()
        }
        wait(for: [executed], timeout: 2)
        worker.stop()
        worker.stop()
    }
}
