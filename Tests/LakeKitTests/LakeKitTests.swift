import XCTest
import Combine
import KeychainSwift
@testable import LakeKit

final class StoreLaunchOverrideTests: XCTestCase {
    func testPretendSubscriptionArgumentIsIgnoredOutsideDebugBuilds() {
        XCTAssertFalse(
            lakeKitPretendSubscriptionEnabled(
                arguments: ["pretend-subscribed"],
                allowsDebugOverrides: false
            )
        )
    }

    func testPretendSubscriptionArgumentIsRecognizedForDebugBuilds() {
        XCTAssertTrue(
            lakeKitPretendSubscriptionEnabled(
                arguments: ["pretend-subscribed"],
                allowsDebugOverrides: true
            )
        )
        XCTAssertFalse(
            lakeKitPretendSubscriptionEnabled(
                arguments: [],
                allowsDebugOverrides: true
            )
        )
    }
}

final class AccountSessionStateTests: XCTestCase {
    @MainActor
    func testSessionRepairsIncompleteStoredCredentialsToSignedOut() {
        let keychain = KeychainSwift(keyPrefix: "LakeKitTests.\(UUID().uuidString).")
        defer { keychain.clear() }
        keychain.set("42", forKey: "userID")

        let session = Session(keychain: keychain)

        XCTAssertEqual(session.observedAccountSessionSnapshot.identity, .signedOut)
        XCTAssertEqual(session.userID, -1)
        XCTAssertFalse(session.isAuthenticated)
        XCTAssertNil(keychain.get("userID"))
    }

    @MainActor
    func testSessionRejectsStoredSignedOutSentinelAsAuthenticatedIdentity() {
        let keychain = KeychainSwift(keyPrefix: "LakeKitTests.\(UUID().uuidString).")
        defer { keychain.clear() }
        keychain.set("token", forKey: "authToken")
        keychain.set("-1", forKey: "userID")

        let session = Session(keychain: keychain)

        XCTAssertEqual(session.observedAccountSessionSnapshot.identity, .signedOut)
        XCTAssertFalse(session.isAuthenticated)
        XCTAssertNil(keychain.get("authToken"))
        XCTAssertNil(keychain.get("userID"))
    }

    @MainActor
    func testCanceledAuthenticationRequirementCannotCompleteSuccessfullyAfterDecision() async {
        let keychain = KeychainSwift(keyPrefix: "LakeKitTests.\(UUID().uuidString).")
        defer { keychain.clear() }
        let session = Session(
            keychain: keychain,
            authenticationPresentationDelayNanoseconds: 100_000_000
        )
        let requirement = Task { @MainActor in
            try await session.requireAuthentication()
        }
        await waitForAuthenticationPresentation(session)

        session.authenticated(authToken: "token", userID: 42)
        requirement.cancel()

        do {
            try await requirement.value
            XCTFail("A canceled authentication requirement must not receive success")
        } catch is CancellationError {
        } catch {
            XCTFail("Expected cancellation, received \(error)")
        }
    }

    @MainActor
    func testLogoutCompletesAuthenticationRequirementThatIsAwaitingDecision() async {
        let keychain = KeychainSwift(keyPrefix: "LakeKitTests.\(UUID().uuidString).")
        defer { keychain.clear() }
        let session = Session(
            keychain: keychain,
            authenticationPresentationDelayNanoseconds: 0
        )
        let requirement = Task { @MainActor in
            try await session.requireAuthentication()
        }
        await waitForAuthenticationPresentation(session)

        session.logout()

        do {
            try await requirement.value
            XCTFail("Logging out must not leave an authentication requirement suspended")
        } catch SessionError.notAuthenticatedAsRequired {
        } catch {
            XCTFail("Expected logout rejection, received \(error)")
        }
    }

    @MainActor
    func testAuthenticationSuccessIsRejectedIfSessionChangesBeforeReturn() async {
        let keychain = KeychainSwift(keyPrefix: "LakeKitTests.\(UUID().uuidString).")
        defer { keychain.clear() }
        let session = Session(
            keychain: keychain,
            authenticationPresentationDelayNanoseconds: 20_000_000
        )
        let requirement = Task { @MainActor in
            try await session.requireAuthentication()
        }
        await waitForAuthenticationPresentation(session)

        session.authenticated(authToken: "token", userID: 42)
        session.logout()

        do {
            try await requirement.value
            XCTFail("A superseded authenticated session must not return success")
        } catch SessionError.notAuthenticatedAsRequired {
        } catch {
            XCTFail("Expected stale-session rejection, received \(error)")
        }
    }

    @MainActor
    func testInvalidAuthenticationPayloadFailsWithoutPersistingPartialCredentials() async {
        let keychain = KeychainSwift(keyPrefix: "LakeKitTests.\(UUID().uuidString).")
        defer { keychain.clear() }
        let session = Session(
            keychain: keychain,
            authenticationPresentationDelayNanoseconds: 0
        )
        let requirement = Task { @MainActor in
            try await session.requireAuthentication()
        }
        await waitForAuthenticationPresentation(session)

        session.authenticated(authToken: "", userID: -1)

        do {
            try await requirement.value
            XCTFail("Invalid credentials must not satisfy an authentication requirement")
        } catch SessionError.credentialStorageFailed {
        } catch {
            XCTFail("Expected credential storage failure, received \(error)")
        }
        XCTAssertEqual(session.observedAccountSessionSnapshot.identity, .signedOut)
        XCTAssertNil(keychain.get("authToken"))
        XCTAssertNil(keychain.get("userID"))
    }

    @MainActor
    func testAuthenticationDecisionOnlyCompletesRequestsItCaptured() async throws {
        let keychain = KeychainSwift(keyPrefix: "LakeKitTests.\(UUID().uuidString).")
        defer { keychain.clear() }
        let session = Session(
            keychain: keychain,
            authenticationPresentationDelayNanoseconds: 10_000_000
        )
        let canceledRequirement = Task { @MainActor in
            try await session.requireAuthentication()
        }
        await waitForAuthenticationPresentation(session)

        session.cancelAuthentication()
        let successfulRequirement = Task { @MainActor in
            try await session.requireAuthentication()
        }
        for _ in 0..<10 {
            await Task.yield()
        }
        session.authenticated(authToken: "token", userID: 42)

        do {
            try await canceledRequirement.value
            XCTFail("The canceled presentation must retain its failure")
        } catch SessionError.notAuthenticatedAsRequired {
        } catch {
            XCTFail("Expected authentication cancellation, received \(error)")
        }
        try await successfulRequirement.value
    }

    @MainActor
    func testSessionPublishesSettledAuthenticationImmediately() {
        let keychain = KeychainSwift(keyPrefix: "LakeKitTests.\(UUID().uuidString).")
        defer { keychain.clear() }
        let session = Session(keychain: keychain)
        var snapshots = [AccountSessionSnapshot]()
        let observation = session.$observedAccountSessionSnapshot.sink {
            snapshots.append($0)
        }

        session.authenticated(authToken: "token", userID: 42)

        XCTAssertTrue(session.isAuthenticated)
        XCTAssertEqual(session.userID, 42)
        XCTAssertEqual(
            session.observedAccountSessionSnapshot,
            AccountSessionSnapshot(identity: .authenticated(userID: 42), generation: 1)
        )
        XCTAssertEqual(snapshots.map(\.identity), [
            .signedOut,
            .transitioning,
            .authenticated(userID: 42),
        ])
        withExtendedLifetime(observation) {}
    }

    func testTransitionSettlementKeepsItsGeneration() {
        var state = AccountSessionState()

        XCTAssertEqual(
            state.beginTransition(),
            AccountSessionSnapshot(identity: .transitioning, generation: 1)
        )
        XCTAssertEqual(
            state.settle(
                identity: .authenticated(userID: 42)
            ),
            AccountSessionSnapshot(identity: .authenticated(userID: 42), generation: 1)
        )
    }

    func testUnannouncedAccountChangeAdvancesGeneration() {
        var state = AccountSessionState()
        _ = state.settle(identity: .authenticated(userID: 42))

        XCTAssertEqual(
            state.settle(
                identity: .authenticated(userID: 7)
            ),
            AccountSessionSnapshot(identity: .authenticated(userID: 7), generation: 2)
        )
    }

    func testSameAccountReauthenticationGetsANewGeneration() {
        var state = AccountSessionState()
        _ = state.settle(identity: .authenticated(userID: 42))

        XCTAssertEqual(state.beginTransition().generation, 2)
        XCTAssertEqual(
            state.settle(
                identity: .authenticated(userID: 42)
            ),
            AccountSessionSnapshot(identity: .authenticated(userID: 42), generation: 2)
        )
    }

    func testUnchangedSettlementDoesNotAdvanceGeneration() {
        var state = AccountSessionState()

        XCTAssertEqual(
            state.settle(identity: .signedOut).generation,
            0
        )
        XCTAssertEqual(
            state.settle(identity: .signedOut).generation,
            0
        )
    }

    func testReplacingAuthorizationInSettledSessionAdvancesGeneration() {
        var state = AccountSessionState()
        _ = state.settle(
            identity: .authenticated(userID: 42),
            authorizationChanged: true
        )

        XCTAssertEqual(
            state.settle(
                identity: .authenticated(userID: 42),
                authorizationChanged: true
            ),
            AccountSessionSnapshot(identity: .authenticated(userID: 42), generation: 2)
        )
    }

    @MainActor
    func testAccessCapturesAuthorizationFromTheMatchingSessionGeneration() throws {
        let keychain = KeychainSwift(keyPrefix: "LakeKitTests.\(UUID().uuidString).")
        defer { keychain.clear() }
        keychain.set("token-a", forKey: "authToken")
        keychain.set("42", forKey: "userID")
        let session = Session(keychain: keychain)
        let access = AccountSessionAccess(session: session)
        let originalSnapshot = access.snapshot

        XCTAssertEqual(
            try XCTUnwrap(access.authorization),
            AccountAuthorizationContext(
                accountSession: originalSnapshot,
                authToken: "token-a"
            )
        )

        XCTAssertTrue(
            SessionCredentialRepository(
                store: SessionCredentialStore(keychain: keychain)
            ).persist(
                SessionCredentials(authToken: "token-b", userID: 42)
            )
        )
        session.updateAuthenticationState()

        XCTAssertNotEqual(access.snapshot, originalSnapshot)
        XCTAssertNil(access.authorization(ifCurrent: originalSnapshot))
        XCTAssertEqual(access.authorization?.authToken, "token-b")
    }

    func testAccessDoesNotAuthorizeSignedOutOrTransitioningSessions() {
        var snapshot = AccountSessionSnapshot(identity: .signedOut, generation: 1)
        let access = AccountSessionAccess(
            testSnapshotProvider: { snapshot },
            authTokenProvider: { "token" }
        )

        XCTAssertNil(access.authorization)

        snapshot = AccountSessionSnapshot(identity: .transitioning, generation: 2)
        XCTAssertNil(access.authorization)
    }

    func testAccessRejectsPublicationFromAStaleGeneration() throws {
        let expected = AccountSessionSnapshot(
            identity: .authenticated(userID: 42),
            generation: 1
        )
        var current = expected
        let access = AccountSessionAccess(testSnapshotProvider: { current })
        current = AccountSessionSnapshot(identity: expected.identity, generation: 2)
        var didPublish = false

        let published = try access.publish(ifCurrent: expected) {
            didPublish = true
        }

        XCTAssertFalse(published)
        XCTAssertFalse(didPublish)
    }

    @MainActor
    func testAccessValuesForOneSessionShareBoundaryIdentity() {
        let keychain = KeychainSwift(keyPrefix: "LakeKitTests.\(UUID().uuidString).")
        defer { keychain.clear() }
        let session = Session(keychain: keychain)

        XCTAssertEqual(
            AccountSessionAccess(session: session).boundaryID,
            AccountSessionAccess(session: session).boundaryID
        )
    }

    func testIndependentInjectedAccessValuesHaveDistinctBoundaryIdentities() {
        let snapshot = AccountSessionSnapshot(identity: .signedOut, generation: 0)

        XCTAssertNotEqual(
            AccountSessionAccess(testSnapshotProvider: { snapshot }).boundaryID,
            AccountSessionAccess(testSnapshotProvider: { snapshot }).boundaryID
        )
    }

    @MainActor
    private func waitForAuthenticationPresentation(_ session: Session) async {
        for _ in 0..<1_000 {
            if session.isPresentingWebAuthentication {
                return
            }
            await Task.yield()
        }
        XCTFail("Timed out waiting for authentication presentation")
    }
}

final class LakeKitPersistedLRUCacheDependencyTests: XCTestCase {
    func testPersistedCacheStoresAndReloadsValues() throws {
        let root = try makeTemporaryRoot()
        let namespace = "lakekit.persisted.\(UUID().uuidString)"

        let cache = PersistedCache<String, String>(
            namespace: namespace,
            compressionThreshold: .max,
            cacheRootURL: root
        )
        cache.setValue(String(repeating: "value", count: 8), forKey: "key")

        XCTAssertEqual(cache.value(forKey: "key"), String(repeating: "value", count: 8))
        XCTAssertEqual(
            PersistedCache<String, String>(
                namespace: namespace,
                compressionThreshold: .max,
                cacheRootURL: root
            ).value(forKey: "key"),
            String(repeating: "value", count: 8)
        )
    }

    func testSQLiteCacheStoresAndReloadsValues() throws {
        let root = try makeTemporaryRoot()
        let namespace = "lakekit.sqlite.\(UUID().uuidString)"

        let cache = LRUSQLiteCache<String, String>(namespace: namespace, cacheRootURL: root)
        cache.setValue("value", forKey: "key")

        XCTAssertEqual(cache.value(forKey: "key"), "value")
        XCTAssertEqual(
            LRUSQLiteCache<String, String>(namespace: namespace, cacheRootURL: root).value(forKey: "key"),
            "value"
        )
    }

    func testFileCacheStoresAndReloadsValues() throws {
        let root = try makeTemporaryRoot()
        let namespace = "lakekit.file.\(UUID().uuidString)"

        let cache = LRUFileCache<String, String>(namespace: namespace, cacheRootURL: root)
        cache.setValue("value", forKey: "key")

        XCTAssertEqual(cache.value(forKey: "key"), "value")
        XCTAssertEqual(
            LRUFileCache<String, String>(namespace: namespace, cacheRootURL: root).value(forKey: "key"),
            "value"
        )
    }

    private func makeTemporaryRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory
                .appendingPathComponent("LakeKitPersistedLRUCacheDependencyTests")
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: root)
        }
        return root
    }
}

final class EnhancedSearchablePlatformPolicyTests: XCTestCase {
    func testResolvedPlacementAndHideabilityMatchPlatformPolicy() {
        XCTAssertFalse(
            EnhancedSearchablePlatformPolicy.canHide(hasPresentationBinding: false)
        )
        let resolvedPlacement = EnhancedSearchablePlatformPolicy.resolvedPlacement(
            .native(.toolbar)
        )

#if os(macOS)
        guard case .contentTop = resolvedPlacement else {
            return XCTFail("macOS enhanced search must use content-top placement")
        }
        XCTAssertFalse(
            EnhancedSearchablePlatformPolicy.canHide(hasPresentationBinding: true)
        )
#else
        guard case .native = resolvedPlacement else {
            return XCTFail("iOS enhanced search must preserve native placement")
        }
        XCTAssertTrue(
            EnhancedSearchablePlatformPolicy.canHide(hasPresentationBinding: true)
        )
#endif
    }
}
