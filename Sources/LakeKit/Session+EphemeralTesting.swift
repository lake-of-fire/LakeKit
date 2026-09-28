#if DEBUG
import Foundation

/// Per-fixture storage, isolated to Session's existing main-actor owner.
/// It is retained by the credential closures, not shared with other sessions.
@MainActor
private final class EphemeralSessionCredentialStorage {
    var data: [String: Data] = [:]
    var strings: [String: String] = [:]
}

public extension Session {
    /// Creates an isolated process-local session without Keychain access.
    /// Uses the real credential repository, validation and account transitions.
    /// Forward-ported from v3-hotfix; the optional delay lets tests avoid waiting
    /// for an animation that does not exist in their fixture.
    /// Never use this API for production authentication or durable credentials.
    @MainActor
    static func ephemeralForTesting(
        authenticationPresentationDelayNanoseconds: UInt64 = 500_000_000
    ) -> Session {
        let storage = EphemeralSessionCredentialStorage()
        return Session(
            credentialStore: SessionCredentialStore(
                data: { storage.data[$0] },
                string: { storage.strings[$0] },
                setData: { storage.data[$1] = $0; return true },
                setString: { storage.strings[$1] = $0; return true },
                delete: {
                    let removedData = storage.data.removeValue(forKey: $0)
                    let removedString = storage.strings.removeValue(forKey: $0)
                    return removedData != nil || removedString != nil
                }
            ),
            authenticationPresentationDelayNanoseconds: authenticationPresentationDelayNanoseconds
        )
    }
}
#endif
