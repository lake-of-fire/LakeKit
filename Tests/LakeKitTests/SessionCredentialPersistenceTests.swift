import Foundation
import XCTest
@testable import LakeKit

final class SessionCredentialPersistenceTests: XCTestCase {
    @MainActor
    func testCanonicalCredentialSlotsRoundTripAndSelectHighestRevision() {
        let store = InMemoryCredentialStore()
        let session = makeSession(using: store)

        session.authenticated(authToken: "first-token", userID: 42)
        session.authenticated(authToken: "second-token", userID: 7)

        XCTAssertEqual(
            store.canonicalRecords.values.map(\.revision).sorted(),
            [1, 2]
        )
        XCTAssertEqual(store.latestCanonicalRecord?.authToken, "second-token")
        XCTAssertEqual(store.latestCanonicalRecord?.userID, 7)

        let reloadedSession = makeSession(using: store)

        XCTAssertEqual(reloadedSession.userID, 7)
        XCTAssertTrue(reloadedSession.isAuthenticated)
        XCTAssertEqual(
            reloadedSession.accountSessionSnapshot.identity,
            .authenticated(userID: 7)
        )
        XCTAssertEqual(
            AccountSessionAccess(session: reloadedSession).authorization?.authToken,
            "second-token"
        )
    }

    @MainActor
    func testLegacyCredentialPairMigratesToCanonicalSlots() {
        let store = InMemoryCredentialStore()
        store.stringValues[CredentialKeys.legacyAuthToken] = "legacy-token"
        store.stringValues[CredentialKeys.legacyUserID] = "42"

        let migratedSession = makeSession(using: store)

        XCTAssertTrue(migratedSession.isAuthenticated)
        XCTAssertEqual(migratedSession.userID, 42)
        XCTAssertEqual(store.latestCanonicalRecord?.authToken, "legacy-token")
        XCTAssertEqual(store.latestCanonicalRecord?.userID, 42)
        XCTAssertEqual(store.latestCanonicalRecord?.revision, 1)

        store.stringValues.removeValue(forKey: CredentialKeys.legacyAuthToken)
        store.stringValues.removeValue(forKey: CredentialKeys.legacyUserID)
        let reloadedSession = makeSession(using: store)

        XCTAssertTrue(reloadedSession.isAuthenticated)
        XCTAssertEqual(reloadedSession.userID, 42)
        XCTAssertEqual(
            reloadedSession.accountSessionSnapshot.identity,
            .authenticated(userID: 42)
        )
    }

    @MainActor
    func testIncompleteLegacyCredentialPairIsRepairedToSignedOut() {
        for incompleteValues in [
            [CredentialKeys.legacyAuthToken: "orphan-token"],
            [CredentialKeys.legacyUserID: "42"],
        ] {
            let store = InMemoryCredentialStore()
            for (key, value) in incompleteValues {
                store.stringValues[key] = value
            }

            let session = makeSession(using: store)

            XCTAssertFalse(session.isAuthenticated)
            XCTAssertEqual(session.userID, -1)
            XCTAssertEqual(session.accountSessionSnapshot.identity, .signedOut)
            XCTAssertTrue(store.stringValues.isEmpty)
            XCTAssertTrue(store.canonicalRecords.isEmpty)
        }
    }

    @MainActor
    func testCanonicalWriteFailureDoesNotPublishRequestedAuthenticatedSession() {
        let store = InMemoryCredentialStore()
        let session = makeSession(using: store)
        session.authenticated(authToken: "durable-token", userID: 42)
        session.authenticated(authToken: "newer-durable-token", userID: 7)

        store.failNextDataWrite = true
        session.authenticated(authToken: "requested-token", userID: 99)

        XCTAssertTrue(session.isAuthenticated)
        XCTAssertEqual(session.userID, 7)
        XCTAssertEqual(
            session.observedAccountSessionSnapshot.identity,
            .authenticated(userID: 7)
        )
        XCTAssertEqual(store.latestCanonicalRecord?.authToken, "newer-durable-token")
        XCTAssertEqual(store.latestCanonicalRecord?.userID, 7)

        let authorization = AccountSessionAccess(session: session).authorization
        XCTAssertEqual(authorization?.accountSession, session.accountSessionSnapshot)
        XCTAssertEqual(authorization?.authToken, "newer-durable-token")
    }

    @MainActor
    func testLogoutDeletionFailureRetainsDurableCurrentSession() {
        let store = InMemoryCredentialStore()
        let session = makeSession(using: store)
        session.authenticated(authToken: "first-token", userID: 42)
        session.authenticated(authToken: "durable-token", userID: 7)
        let previousSnapshot = session.accountSessionSnapshot
        guard let currentCanonicalKey = store.latestCanonicalKey else {
            XCTFail("Expected a durable canonical credential record")
            return
        }
        store.failingDeleteKeys.insert(currentCanonicalKey)

        let removedCredentials = session.logout()

        XCTAssertFalse(removedCredentials)
        XCTAssertTrue(session.isAuthenticated)
        XCTAssertEqual(session.userID, 7)
        XCTAssertEqual(
            session.observedAccountSessionSnapshot.identity,
            .authenticated(userID: 7)
        )
        XCTAssertEqual(
            session.accountSessionSnapshot.generation,
            previousSnapshot.generation &+ 1
        )
        XCTAssertEqual(store.latestCanonicalRecord?.authToken, "durable-token")
        XCTAssertEqual(store.latestCanonicalRecord?.userID, 7)

        let reloadedSession = makeSession(using: store)
        XCTAssertTrue(reloadedSession.isAuthenticated)
        XCTAssertEqual(reloadedSession.userID, 7)
    }

    @MainActor
    func testLogoutDoesNotDeleteCurrentAccountWhenSupersededSlotCleanupFails() {
        let store = InMemoryCredentialStore()
        let session = makeSession(using: store)
        session.authenticated(authToken: "old-token", userID: 42)
        let stalePrimaryData = store.dataValues[CredentialKeys.canonicalPrimary]
        session.authenticated(authToken: "current-token", userID: 7)
        store.dataValues[CredentialKeys.canonicalPrimary] = stalePrimaryData
        store.failingDeleteKeys.insert(CredentialKeys.canonicalPrimary)

        XCTAssertFalse(session.logout())

        XCTAssertTrue(session.isAuthenticated)
        XCTAssertEqual(session.userID, 7)
        XCTAssertEqual(
            AccountSessionAccess(session: session).authorization?.authToken,
            "current-token"
        )
        XCTAssertNotNil(store.dataValues[CredentialKeys.canonicalSecondary])
    }

    @MainActor
    func testAccountAuthorizationBindsTokenToCurrentSessionGeneration() {
        let store = InMemoryCredentialStore()
        let session = makeSession(using: store)
        session.authenticated(authToken: "first-token", userID: 42)
        let access = AccountSessionAccess(session: session)
        let firstSnapshot = session.accountSessionSnapshot

        XCTAssertEqual(access.authorization?.accountSession, firstSnapshot)
        XCTAssertEqual(access.authorization?.authToken, "first-token")

        session.authenticated(authToken: "second-token", userID: 42)
        let secondSnapshot = session.accountSessionSnapshot

        XCTAssertNotEqual(firstSnapshot.generation, secondSnapshot.generation)
        XCTAssertEqual(access.authorization?.accountSession, secondSnapshot)
        XCTAssertEqual(access.authorization?.authToken, "second-token")
        XCTAssertNil(access.authorization(ifCurrent: firstSnapshot))
        XCTAssertEqual(
            access.authorization(ifCurrent: secondSnapshot)?.authToken,
            "second-token"
        )
    }

    @MainActor
    func testReloadingReplacementTokenInvalidatesSameUserSessionGeneration() throws {
        let store = InMemoryCredentialStore()
        let session = makeSession(using: store)
        session.authenticated(authToken: "first-token", userID: 42)
        let access = AccountSessionAccess(session: session)
        let firstSnapshot = session.accountSessionSnapshot

        XCTAssertTrue(
            SessionCredentialRepository(store: store.credentialStore).persist(
                SessionCredentials(authToken: "replacement-token", userID: 42)
            )
        )
        session.updateAuthenticationState()

        let replacementSnapshot = session.accountSessionSnapshot
        XCTAssertNotEqual(replacementSnapshot.generation, firstSnapshot.generation)
        XCTAssertEqual(replacementSnapshot.identity, firstSnapshot.identity)
        XCTAssertNil(access.authorization(ifCurrent: firstSnapshot))
        XCTAssertEqual(
            access.authorization(ifCurrent: replacementSnapshot)?.authToken,
            "replacement-token"
        )

        session.updateAuthenticationState()
        XCTAssertEqual(session.accountSessionSnapshot, replacementSnapshot)
    }

    @MainActor
    private func makeSession(using store: InMemoryCredentialStore) -> Session {
        Session(
            credentialStore: store.credentialStore,
            authenticationPresentationDelayNanoseconds: 0
        )
    }
}

private enum CredentialKeys {
    static let canonicalPrimary = "accountCredentials.v1.primary"
    static let canonicalSecondary = "accountCredentials.v1.secondary"
    static let canonicalSlots = [canonicalPrimary, canonicalSecondary]
    static let legacyAuthToken = "authToken"
    static let legacyUserID = "userID"
}

private struct StoredCredentialFixture: Codable, Equatable {
    let authToken: String
    let userID: Int
    let revision: UInt64
}

private final class InMemoryCredentialStore {
    var dataValues = [String: Data]()
    var stringValues = [String: String]()
    var failNextDataWrite = false
    var failingDeleteKeys = Set<String>()

    var credentialStore: SessionCredentialStore {
        SessionCredentialStore(
            data: { [self] key in
                dataValues[key]
            },
            string: { [self] key in
                stringValues[key]
            },
            setData: { [self] data, key in
                if failNextDataWrite {
                    failNextDataWrite = false
                    // Match KeychainSwift.set's delete-before-add failure behavior.
                    dataValues.removeValue(forKey: key)
                    return false
                }
                dataValues[key] = data
                return true
            },
            setString: { [self] value, key in
                stringValues[key] = value
                return true
            },
            delete: { [self] key in
                guard !failingDeleteKeys.contains(key) else { return false }
                dataValues.removeValue(forKey: key)
                stringValues.removeValue(forKey: key)
                return true
            }
        )
    }

    var canonicalRecords: [String: StoredCredentialFixture] {
        Dictionary(uniqueKeysWithValues: CredentialKeys.canonicalSlots.compactMap { key in
            guard let data = dataValues[key],
                  let record = try? JSONDecoder().decode(
                      StoredCredentialFixture.self,
                      from: data
                  ) else { return nil }
            return (key, record)
        })
    }

    var latestCanonicalKey: String? {
        canonicalRecords.max {
            $0.value.revision < $1.value.revision
        }?.key
    }

    var latestCanonicalRecord: StoredCredentialFixture? {
        guard let key = latestCanonicalKey else { return nil }
        return canonicalRecords[key]
    }
}
