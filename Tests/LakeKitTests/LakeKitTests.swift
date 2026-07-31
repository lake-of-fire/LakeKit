import XCTest
import Combine
import BigSyncKit
import RealmSwift
import RealmSwiftGaps
@testable import LakeKit

final class ReferralCodeUsageMutationTrackingTests: XCTestCase {
    @RealmBackgroundActor
    func testCreateRecordsDurableBigSyncMutationAfterAddingUsage() async throws {
        var configuration = Realm.Configuration(
            inMemoryIdentifier: UUID().uuidString
        )
        configuration.objectTypes = [
            ReferralCodeUsage.self,
            BigSyncPendingMutation.self,
        ]
        BigSyncMutationTracking.install(
            configurations: [configuration],
            excludedClassNames: []
        )

        let usage = try await ReferralCodeUsage.create(
            referralCode: "referral",
            receipt: "receipt",
            realmConfiguration: configuration
        )
        let realm = try await RealmBackgroundActor.shared.cachedRealm(
            for: configuration
        )
        let recordName = "ReferralCodeUsage.\(usage.id.uuidString)"
        let mutation = realm.object(
            ofType: BigSyncPendingMutation.self,
            forPrimaryKey: recordName
        )

        XCTAssertNotNil(mutation)
        XCTAssertEqual(mutation?.entityType, ReferralCodeUsage.className())
        XCTAssertEqual(mutation?.objectIdentifier, usage.id.uuidString)
        XCTAssertEqual(usage.explicitlyModifiedAt, mutation?.changedAt)
    }
}

final class AccountSessionStateTests: XCTestCase {
    @MainActor
    func testSessionRepairsIncompleteStoredCredentialsToSignedOut() {
        let store = InMemoryCredentialStore()
        store.stringValues[CredentialKeys.legacyUserID] = "42"

        let session = makeSession(using: store)

        XCTAssertEqual(session.observedAccountSessionSnapshot.identity, .signedOut)
        XCTAssertEqual(session.userID, -1)
        XCTAssertFalse(session.isAuthenticated)
        XCTAssertNil(store.stringValues[CredentialKeys.legacyUserID])
    }

    @MainActor
    func testSessionRejectsStoredSignedOutSentinelAsAuthenticatedIdentity() {
        let store = InMemoryCredentialStore()
        store.stringValues[CredentialKeys.legacyAuthToken] = "token"
        store.stringValues[CredentialKeys.legacyUserID] = "-1"

        let session = makeSession(using: store)

        XCTAssertEqual(session.observedAccountSessionSnapshot.identity, .signedOut)
        XCTAssertFalse(session.isAuthenticated)
        XCTAssertNil(store.stringValues[CredentialKeys.legacyAuthToken])
        XCTAssertNil(store.stringValues[CredentialKeys.legacyUserID])
    }

    @MainActor
    func testCanceledAuthenticationRequirementCannotCompleteSuccessfullyAfterDecision() async {
        let session = makeSession(
            using: InMemoryCredentialStore(),
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
        let session = makeSession(
            using: InMemoryCredentialStore(),
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
        let session = makeSession(
            using: InMemoryCredentialStore(),
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
        let store = InMemoryCredentialStore()
        let session = makeSession(using: store)
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
        XCTAssertNil(store.stringValues[CredentialKeys.legacyAuthToken])
        XCTAssertNil(store.stringValues[CredentialKeys.legacyUserID])
    }

    @MainActor
    func testAuthenticationDecisionOnlyCompletesRequestsItCaptured() async throws {
        let session = makeSession(
            using: InMemoryCredentialStore(),
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
        let session = makeSession(using: InMemoryCredentialStore())
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
    private func waitForAuthenticationPresentation(_ session: Session) async {
        for _ in 0..<1_000 {
            if session.isPresentingWebAuthentication {
                return
            }
            await Task.yield()
        }
        XCTFail("Timed out waiting for authentication presentation")
    }

    @MainActor
    private func makeSession(
        using store: InMemoryCredentialStore,
        authenticationPresentationDelayNanoseconds: UInt64 = 0
    ) -> Session {
        Session(
            credentialStore: store.credentialStore,
            authenticationPresentationDelayNanoseconds:
                authenticationPresentationDelayNanoseconds
        )
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

final class AccountSessionBoundaryIdentityTests: XCTestCase {
    @MainActor
    func testAccessValuesForOneSessionShareBoundaryIdentity() {
        let store = InMemoryCredentialStore()
        let session = Session(
            credentialStore: store.credentialStore,
            authenticationPresentationDelayNanoseconds: 0
        )

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
}
