import Foundation

/// The completion and its cancellation check run together on the UI actor.
/// A canceled navigation must not hide its successor's progress indicator.
@MainActor
enum LocationBarProgressHide {
    static func run(
        after delay: TimeInterval,
        sleep: @MainActor (UInt64) async throws -> Void = {
            try await Task.sleep(nanoseconds: $0)
        },
        completion: @MainActor () -> Void
    ) async {
        do {
            try Task.checkCancellation()
            try await sleep(UInt64(delay * 1_000_000_000))
            // Also reject a cancellation racing a successful/non-cooperative sleep.
            try Task.checkCancellation()
        } catch {
            return
        }
        completion()
    }
}
