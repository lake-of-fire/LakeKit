//// Forked from: https://gist.github.com/rnapier/af027808dcfca84686f063963e2a29f5
//
//import Foundation.NSDate // for TimeInterval
//
//func firstResult<R>(from tasks: [() async throws -> R]) async throws -> R? {
//    return try await withThrowingTaskGroup(of: R.self) { group in
//        for task in tasks {
//            group.addTask { try await task() }
//        }
//        // First finished child task wins, cancel the other task.
//        let result = try await group.next()
//        group.cancelAll()
//        return result
//    }
//}
//
//struct TimedOutError: Error, Equatable {}
//func timeout<R>(seconds: TimeInterval) -> () async throws -> R {
//    return {
//        try await Task.sleep(nanoseconds: UInt64(seconds * TimeInterval(NSEC_PER_SEC)))
//        try Task.checkCancellation()
//        throw TimedOutError()
//    }
//}
//
///// Runs an async task with a timeout.
/////
///// - Parameters:
/////   - maxDuration: The duration in seconds `work` is allowed to run before timing out.
/////   - work: The async operation to perform.
///// - Returns: Returns the result of `work` if it completed in time.
///// - Throws: Throws ``TimedOutError`` if the timeout expires before `work` completes.
/////   If `work` throws an error before the timeout expires, that error is propagated to the caller.
//func `async`<R>(
//    timeoutAfter maxDuration: TimeInterval,
//    do work: @escaping () async throws -> R
//) async throws -> R {
//    try await firstResult(from: [work, timeout(seconds: maxDuration)])!
//}
