import SwiftUI
import KeychainSwift
import BetterSafariView

public enum AccountSessionIdentity: Hashable, Sendable {
    case signedOut
    case transitioning
    case authenticated(userID: Int)

    public var authenticatedUserID: Int? {
        guard case let .authenticated(userID) = self else { return nil }
        return userID
    }
}

public struct AccountSessionSnapshot: Hashable, Sendable {
    public let identity: AccountSessionIdentity
    public let generation: UInt64

    public init(identity: AccountSessionIdentity, generation: UInt64) {
        self.identity = identity
        self.generation = generation
    }
}

/// Request-scoped authorization captured from the same locked state as its
/// account identity. The token is intentionally absent from observable session
/// state; networking code should carry this value only for the lifetime of a
/// request or sync run.
public struct AccountAuthorizationContext: Hashable, Sendable {
    public let accountSession: AccountSessionSnapshot
    public let authToken: String

    public init(accountSession: AccountSessionSnapshot, authToken: String) {
        self.accountSession = accountSession
        self.authToken = authToken
    }
}

struct AccountSessionState: Equatable, Sendable {
    private(set) var snapshot = AccountSessionSnapshot(
        identity: .signedOut,
        generation: 0
    )

    mutating func beginTransition() -> AccountSessionSnapshot {
        snapshot = AccountSessionSnapshot(
            identity: .transitioning,
            generation: snapshot.generation &+ 1
        )
        return snapshot
    }

    mutating func settle(
        identity: AccountSessionIdentity,
        authorizationChanged: Bool = false
    ) -> AccountSessionSnapshot {
        let identityChanged = snapshot.identity != identity
        let beginsUnannouncedTransition = identityChanged && snapshot.identity != .transitioning
        let replacesAuthorizationInSettledSession = authorizationChanged
            && snapshot.identity == identity
            && snapshot.identity != .transitioning
        let generation = beginsUnannouncedTransition || replacesAuthorizationInSettledSession
            ? snapshot.generation &+ 1
            : snapshot.generation
        snapshot = AccountSessionSnapshot(identity: identity, generation: generation)
        return snapshot
    }
}

/// Stable identity for one account-session publication boundary. Multiple access
/// values created from the same `Session` share this identity, while independently
/// injected boundaries remain isolated even when their snapshots happen to match.
public struct AccountSessionBoundaryID: Hashable, Sendable {
    fileprivate let rawValue: UUID

    init() {
        rawValue = UUID()
    }
}

/// One coherent boundary for reading account identity and conditionally publishing
/// work derived from it. Production access wraps `Session`'s lock so an account
/// transition cannot begin during the publication closure.
public struct AccountSessionAccess: @unchecked Sendable {
    public let boundaryID: AccountSessionBoundaryID
    private let snapshotProvider: () -> AccountSessionSnapshot
    private let authorizationProvider: (
        AccountSessionSnapshot?
    ) -> AccountAuthorizationContext?
    private let publicationFence: (
        AccountSessionSnapshot,
        () throws -> Void
    ) throws -> Bool

    public init(session: Session) {
        boundaryID = session.accountSessionBoundaryID
        snapshotProvider = { session.accountSessionSnapshot }
        authorizationProvider = { expected in
            session.accountAuthorization(matching: expected)
        }
        publicationFence = { expected, publish in
            try session.withAccountSession(matching: expected) {
                try publish()
                return true
            } == true
        }
    }

    /// Creates an access boundary for deterministic tests whose provider does not
    /// mutate concurrently with publication. Production code must use `init(session:)`.
    init(
        boundaryID: AccountSessionBoundaryID = AccountSessionBoundaryID(),
        testSnapshotProvider snapshotProvider: @escaping () -> AccountSessionSnapshot,
        authTokenProvider: @escaping () -> String? = { "test-auth-token" }
    ) {
        self.boundaryID = boundaryID
        self.snapshotProvider = snapshotProvider
        authorizationProvider = { expected in
            let snapshot = snapshotProvider()
            guard expected == nil || snapshot == expected,
                  case .authenticated = snapshot.identity,
                  let authToken = authTokenProvider(),
                  !authToken.isEmpty else { return nil }
            return AccountAuthorizationContext(
                accountSession: snapshot,
                authToken: authToken
            )
        }
        publicationFence = { expected, publish in
            guard snapshotProvider() == expected else { return false }
            try publish()
            return true
        }
    }

    public var snapshot: AccountSessionSnapshot {
        snapshotProvider()
    }

    public var authorization: AccountAuthorizationContext? {
        authorizationProvider(nil)
    }

    public func authorization(
        ifCurrent expected: AccountSessionSnapshot
    ) -> AccountAuthorizationContext? {
        authorizationProvider(expected)
    }

    public func publish(
        ifCurrent expected: AccountSessionSnapshot,
        _ operation: () throws -> Void
    ) throws -> Bool {
        // `operation` runs while the Session publication fence is held. Derive all
        // inputs beforehand; keep this closure to bounded compare-and-set writes.
        try publicationFence(expected, operation)
    }
}

public extension Notification.Name {
    static var userAuthenticationChanged: Notification.Name {
        .init("userAuthenticationChanged")
    }
}

extension Notification {
    static var userAuthenticationChanged: Notification {
        Notification(name: .userAuthenticationChanged)
    }
}

@MainActor
public class Session: ObservableObject {
    private static let defaultAuthenticationPresentationDelayNanoseconds: UInt64 = 500_000_000

    private let credentialRepository: SessionCredentialRepository
    private let authenticationPresentationDelayNanoseconds: UInt64
    fileprivate nonisolated let accountSessionBoundaryID = AccountSessionBoundaryID()
    /// Lock-backed account ID for non-main-actor callers. Transitional and signed-out
    /// sessions deliberately read as the historical `-1` sentinel.
    public nonisolated var fastUserID: Int {
        accountSessionSnapshot.identity.authenticatedUserID ?? -1
    }

    @Published public var isPresentingWebAuthentication = false
    
    /// -1 means logged out.
    @Published public private(set) var userID: Int = -1
    
    private var authenticationDecisionWaiters = [UUID: CheckedContinuation<Void, Error>]()
    private var authenticationDismissalWaiters = [UUID: CheckedContinuation<Void, Error>]()
    
    @Published public private(set) var isAuthenticated: Bool = false
    /// Main-actor observable mirror of `accountSessionSnapshot`. Consumers that
    /// need coherent identity should observe this value instead of separate fields.
    @Published public private(set) var observedAccountSessionSnapshot = AccountSessionSnapshot(
        identity: .signedOut,
        generation: 0
    )

    private nonisolated let accountSessionStateLock = NSLock()
    private nonisolated(unsafe) var accountSessionState = AccountSessionState()
    private nonisolated(unsafe) var accountAuthorizationToken: String?

    /// A causal, thread-safe authentication snapshot for background work. Unlike
    /// separately reading `userID` and `isAuthenticated`, this distinguishes two
    /// sessions for the same account and exposes intermediate login/logout states.
    public nonisolated var accountSessionSnapshot: AccountSessionSnapshot {
        withLockedAccountSessionState { $0.snapshot }
    }

    fileprivate nonisolated func accountAuthorization(
        matching expected: AccountSessionSnapshot? = nil
    ) -> AccountAuthorizationContext? {
        withLockedAccountSessionState { state in
            let snapshot = state.snapshot
            guard expected == nil || snapshot == expected,
                  case .authenticated = snapshot.identity,
                  let authToken = accountAuthorizationToken,
                  !authToken.isEmpty else { return nil }
            return AccountAuthorizationContext(
                accountSession: snapshot,
                authToken: authToken
            )
        }
    }

    /// Runs a short synchronous publication only while `expected` is still the
    /// current account session. The closure must not call back into `Session`.
    fileprivate nonisolated func withAccountSession<Result>(
        matching expected: AccountSessionSnapshot,
        perform: () throws -> Result
    ) rethrows -> Result? {
        try withLockedAccountSessionState { state in
            guard state.snapshot == expected else { return nil }
            return try perform()
        }
    }

    public convenience init(keychain: KeychainSwift) {
        self.init(
            credentialStore: SessionCredentialStore(keychain: keychain),
            authenticationPresentationDelayNanoseconds:
                Self.defaultAuthenticationPresentationDelayNanoseconds
        )
    }

    init(
        keychain: KeychainSwift,
        authenticationPresentationDelayNanoseconds: UInt64
    ) {
        credentialRepository = SessionCredentialRepository(
            store: SessionCredentialStore(keychain: keychain)
        )
        self.authenticationPresentationDelayNanoseconds =
            authenticationPresentationDelayNanoseconds
        settleAuthenticationState()
    }

    init(
        credentialStore: SessionCredentialStore,
        authenticationPresentationDelayNanoseconds: UInt64
    ) {
        credentialRepository = SessionCredentialRepository(store: credentialStore)
        self.authenticationPresentationDelayNanoseconds =
            authenticationPresentationDelayNanoseconds
        settleAuthenticationState()
    }

    @MainActor
    public func updateAuthenticationState() {
        settleAuthenticationState()
    }

    private func settleAuthenticationState() {
        let credentials = credentialRepository.load()
        publishSettledAuthentication(credentials)
    }

    private func publishSettledAuthentication(_ credentials: SessionCredentials?) {
        let previousUserID = userID
        let newUserID = credentials?.userID ?? -1
        let newIsAuthenticated = credentials != nil
        let accountIdentityChanged = previousUserID != newUserID
            || isAuthenticated != newIsAuthenticated
        // Publish the causal snapshot before exposing the raw Boolean. Any work
        // observing a mixed pair then fails its generation/identity validation.
        let sessionSnapshot = settleAccountSession(
            identity: credentials.map { .authenticated(userID: $0.userID) } ?? .signedOut,
            authToken: credentials?.authToken
        )
        publishAccountSessionSnapshot(sessionSnapshot)
        if userID != newUserID {
            userID = newUserID
        }
        if isAuthenticated != newIsAuthenticated {
            isAuthenticated = newIsAuthenticated
        }
        if accountIdentityChanged {
            NotificationCenter.default.post(.userAuthenticationChanged)
        }
    }
    
    /// Returns immediately for an authenticated session. Otherwise, presents the
    /// shared web-authentication UI and suspends this caller until that presentation
    /// succeeds, fails, or this caller is canceled. Concurrent callers share the UI
    /// but retain independent continuation ownership.
    public func requireAuthentication() async throws {
        let waiterID = UUID()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation {
                (continuation: CheckedContinuation<Void, Error>) in
                guard !Task.isCancelled else {
                    continuation.resume(throwing: CancellationError())
                    return
                }
                if isAuthenticated {
                    continuation.resume()
                    return
                }
                authenticationDecisionWaiters[waiterID] = continuation
                if !isPresentingWebAuthentication {
                    isPresentingWebAuthentication = true
                }
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                self?.cancelAuthenticationWaiter(id: waiterID)
            }
        }
    }
    
    @MainActor
    public func authenticated(authToken: String, userID: Int) {
        beginAccountSessionTransition()
        let credentials = SessionCredentials(authToken: authToken, userID: userID)
        let storedRequestedSession = credentials.isValid
            && credentialRepository.persist(credentials)
        if storedRequestedSession {
            publishSettledAuthentication(credentials)
        } else {
            // The alternating canonical slots preserve the previous complete
            // login when validation or persistence fails. Re-publish that durable
            // state instead of turning a failed replacement into an implicit logout.
            settleAuthenticationState()
        }
        let publishedRequestedSession = storedRequestedSession
            && observedAccountSessionSnapshot.identity == .authenticated(userID: userID)
        let result: Result<Void, Error> = publishedRequestedSession
            ? .success(())
            : .failure(SessionError.credentialStorageFailed)
        completeAuthenticationWaiters(
            with: result,
            requiringCurrentSession: publishedRequestedSession
                ? observedAccountSessionSnapshot
                : nil
        )
    }
    
    public func cancelAuthentication(error: Error? = nil) {
        _ = settleSignedOut(
            completingAuthenticationWaitersWith:
                .failure(error ?? SessionError.notAuthenticatedAsRequired)
        )
    }

    @MainActor
    @discardableResult
    public func logout() -> Bool {
        settleSignedOut(
            completingAuthenticationWaitersWith:
                .failure(SessionError.notAuthenticatedAsRequired)
        )
    }

    @MainActor
    private func settleSignedOut(
        completingAuthenticationWaitersWith result: Result<Void, Error>
    ) -> Bool {
        beginAccountSessionTransition()
        let removedCredentials = credentialRepository.remove()
        if removedCredentials {
            publishSettledAuthentication(nil)
        } else {
            settleAuthenticationState()
        }
        completeAuthenticationWaiters(with: result)
        return removedCredentials
    }

    @MainActor
    private func beginAccountSessionTransition() {
        let snapshot = withLockedAccountSessionState {
            accountAuthorizationToken = nil
            return $0.beginTransition()
        }
        publishAccountSessionSnapshot(snapshot)
    }

    @MainActor
    private func settleAccountSession(
        identity: AccountSessionIdentity,
        authToken: String?
    ) -> AccountSessionSnapshot {
        return withLockedAccountSessionState {
            let authorizationChanged = accountAuthorizationToken != authToken
            accountAuthorizationToken = authToken
            return $0.settle(
                identity: identity,
                authorizationChanged: authorizationChanged
            )
        }
    }

    private func publishAccountSessionSnapshot(_ snapshot: AccountSessionSnapshot) {
        guard observedAccountSessionSnapshot != snapshot else { return }
        observedAccountSessionSnapshot = snapshot
    }

    private func cancelAuthenticationWaiter(id: UUID) {
        let continuation = authenticationDecisionWaiters.removeValue(forKey: id)
            ?? authenticationDismissalWaiters.removeValue(forKey: id)
        continuation?.resume(throwing: CancellationError())
    }

    private func completeAuthenticationWaiters(
        with result: Result<Void, Error>,
        requiringCurrentSession expectedSession: AccountSessionSnapshot? = nil
    ) {
        guard !authenticationDecisionWaiters.isEmpty else { return }
        let waiters = authenticationDecisionWaiters
        authenticationDecisionWaiters.removeAll(keepingCapacity: true)
        for (id, continuation) in waiters {
            authenticationDismissalWaiters[id] = continuation
        }
        let delay = authenticationPresentationDelayNanoseconds
        Task { @MainActor in
            // State settles immediately, but callers resume after the authentication
            // sheet's dismissal animation so they do not present over that sheet.
            try? await Task.sleep(nanoseconds: delay)
            let completionResult: Result<Void, Error> = if let expectedSession,
                accountSessionSnapshot != expectedSession {
                .failure(SessionError.notAuthenticatedAsRequired)
            } else {
                result
            }
            for id in waiters.keys {
                authenticationDismissalWaiters.removeValue(forKey: id)?
                    .resume(with: completionResult)
            }
        }
    }

    private nonisolated func withLockedAccountSessionState<Result>(
        _ operation: (inout AccountSessionState) throws -> Result
    ) rethrows -> Result {
        accountSessionStateLock.lock()
        defer { accountSessionStateLock.unlock() }
        return try operation(&accountSessionState)
    }
}

public enum SessionError: Error, Equatable, Sendable {
    case notAuthenticatedAsRequired
    case credentialStorageFailed
}

public extension View {
    func lakeAuthenticationSession(
        isActive: Bool,
        session: Session
    ) -> some View {
        self.modifier(
            LakeAuthenticationSessionModifier(
                isActive: isActive,
                session: session
            )
        )
    }
}

public struct LakeAuthenticationSessionModifier: ViewModifier {
    let isActive: Bool
    
    @MainActor @ObservedObject public var session: Session

    public func body(content: Content) -> some View {
        content
            .webAuthenticationSession(isPresented: $session.isPresentingWebAuthentication.gatedBy(isActive)) {
                WebAuthenticationSession(url: URL(string: "https://manabi.io/accounts/signup/?next=/accounts/native-app-login-redirect/manabireader/")!, callbackURLScheme: "manabireader") { callbackURL, error in
                    if let error {
                        print(error)
                        if !session.isAuthenticated {
                            session.cancelAuthentication(error: error)
                        }
                        return
                    }
                    guard let callbackURL = callbackURL, let components = NSURLComponents(url: callbackURL, resolvingAgainstBaseURL: true), let scheme = components.scheme, scheme == "manabireader", let host = components.host else {
                        print("Invalid URL \(callbackURL?.absoluteString ?? "(unknown URL)")")
                        session.cancelAuthentication()
                        return
                    }
                    if host == "login-success" || host == "signup-success", let queryItems = components.queryItems {
                        var foundAuthToken: String?, foundUserID: Int?
                        for queryItem in queryItems {
                            if queryItem.name == "authToken", let authToken = queryItem.value, !authToken.isEmpty {
                                foundAuthToken = authToken
                            } else if queryItem.name == "userID", let userIDString = queryItem.value, let userID = Int(userIDString) {
                                foundUserID = userID
                            }
                        }
                        if let authToken = foundAuthToken, let userID = foundUserID {
                            session.authenticated(authToken: authToken, userID: userID)
                            return
                        }
                    }
                    session.cancelAuthentication()
                }
                .prefersEphemeralWebBrowserSession(true)
            }
    }
}
