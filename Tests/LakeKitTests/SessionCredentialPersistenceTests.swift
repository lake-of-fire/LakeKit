import Foundation
import XCTest
import KeychainSwift
import Security
@testable import LakeKit

final class SessionCredentialPersistenceTests: XCTestCase {
    @MainActor
    func testEphemeralSessionPublishesCredentialsWithoutSharingThem() {
        let session = Session.ephemeralForTesting()
        session.authenticated(authToken: "fixture-token", userID: 42)

        XCTAssertEqual(
            session.accountSessionSnapshot.identity,
            .authenticated(userID: 42)
        )
        XCTAssertEqual(
            AccountSessionAccess(session: session).authorization?.authToken,
            "fixture-token"
        )
        XCTAssertEqual(
            Session.ephemeralForTesting().accountSessionSnapshot.identity,
            .signedOut
        )
    }

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
    func testCredentialRecordIdentityMatchesDurableRecordAndSurvivesRestart() {
        let store = InMemoryCredentialStore()
        let session = makeSession(using: store)

        session.authenticated(authToken: "same-token", userID: 42)
        let original = AccountSessionAccess(session: session).authorization?.credentialRecordID

        XCTAssertNotNil(original)
        XCTAssertEqual(original, store.latestCanonicalRecord?.recordID)

        let restarted = makeSession(using: store)
        XCTAssertEqual(
            AccountSessionAccess(session: restarted).authorization?.credentialRecordID,
            original
        )

        let beforeRefresh = session.accountSessionSnapshot
        session.updateAuthenticationState()
        XCTAssertEqual(session.accountSessionSnapshot, beforeRefresh)

        session.authenticated(authToken: "same-token", userID: 42)
        let refreshedCredentialRecordID =
            AccountSessionAccess(session: session).authorization?.credentialRecordID
        XCTAssertNotEqual(refreshedCredentialRecordID, original)
        XCTAssertEqual(refreshedCredentialRecordID, store.latestCanonicalRecord?.recordID)
        XCTAssertNotEqual(session.accountSessionSnapshot.generation, beforeRefresh.generation)
    }

    @MainActor
    func testOldCredentialRecordUpgradesStableIdentityWithoutChangingLogin() throws {
        let store = InMemoryCredentialStore()
        store.dataValues[CredentialKeys.canonicalPrimary] = try JSONSerialization.data(
            withJSONObject: [
                "authToken": "legacy-token",
                "userID": 42,
                "revision": 1,
            ]
        )

        let session = makeSession(using: store)
        let identity = AccountSessionAccess(session: session).authorization?.credentialRecordID

        XCTAssertNotNil(identity)
        XCTAssertEqual(identity, store.latestCanonicalRecord?.recordID)
        XCTAssertEqual(session.userID, 42)
        XCTAssertEqual(
            AccountSessionAccess(session: makeSession(using: store)).authorization?.credentialRecordID,
            identity
        )
    }

    @MainActor
    func testFailedCredentialIdentityUpgradePreservesLoginWithoutInventingDurableAuthority() throws {
        let store = InMemoryCredentialStore()
        store.dataValues[CredentialKeys.canonicalPrimary] = try JSONSerialization.data(
            withJSONObject: [
                "authToken": "legacy-token",
                "userID": 42,
                "revision": 1,
            ]
        )
        store.failNextDataWrite = true

        let session = makeSession(using: store)

        XCTAssertEqual(session.userID, 42)
        XCTAssertTrue(session.isAuthenticated)
        XCTAssertNil(AccountSessionAccess(session: session).authorization?.credentialRecordID)
        XCTAssertNil(store.latestCanonicalRecord?.recordID)
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
    func testLegacyMigrationWithUnavailableReadbackPreservesLoginAndRecoversDurableIdentity() throws {
        let store = InMemoryCredentialStore()
        store.stringValues[CredentialKeys.legacyAuthToken] = "legacy-token"
        store.stringValues[CredentialKeys.legacyUserID] = "42"
        let underlying = store.credentialStore
        var canonicalReadbackIsUnavailable = false
        let session = Session(
            credentialStore: SessionCredentialStore(
                data: { key in
                    if canonicalReadbackIsUnavailable, CredentialKeys.canonicalSlots.contains(key) {
                        return .unavailable
                    }
                    return underlying.data(key)
                },
                string: underlying.string,
                setData: { data, key in
                    guard underlying.setData(data, key) else { return false }
                    canonicalReadbackIsUnavailable = true
                    return true
                },
                setString: underlying.setString,
                delete: underlying.delete
            ),
            authenticationPresentationDelayNanoseconds: 0
        )
        let access = AccountSessionAccess(session: session)
        let beforeReadback = session.accountSessionSnapshot
        XCTAssertTrue(session.isAuthenticated)
        XCTAssertEqual(session.userID, 42)
        XCTAssertEqual(access.authorization?.authToken, "legacy-token")
        XCTAssertNil(access.authorization?.credentialRecordID)
        let storedIdentity = try XCTUnwrap(store.latestCanonicalRecord?.recordID)

        canonicalReadbackIsUnavailable = false
        session.updateAuthenticationState()
        XCTAssertTrue(session.isAuthenticated)
        XCTAssertEqual(session.userID, 42)
        XCTAssertEqual(access.authorization?.credentialRecordID, storedIdentity)
        XCTAssertNotEqual(session.accountSessionSnapshot.generation, beforeReadback.generation)
        XCTAssertNil(access.authorization(ifCurrent: beforeReadback))

        let afterReadback = session.accountSessionSnapshot
        session.updateAuthenticationState()
        XCTAssertEqual(session.accountSessionSnapshot, afterReadback)
        XCTAssertEqual(store.canonicalRecords.count, 1)
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
    func testUnavailableCanonicalReadsCannotPublishSuccessfulLogout() {
        let store = InMemoryCredentialStore()
        let session = makeSession(using: store)
        session.authenticated(authToken: "first-token", userID: 42)
        session.authenticated(authToken: "current-token", userID: 7)
        let records = store.dataValues
        store.unavailableReadKeys.formUnion(CredentialKeys.canonicalSlots)

        XCTAssertFalse(session.logout())
        XCTAssertTrue(session.isAuthenticated)
        XCTAssertEqual(session.userID, 7)
        XCTAssertEqual(AccountSessionAccess(session: session).authorization?.authToken, "current-token")
        XCTAssertEqual(store.dataValues, records)

        store.unavailableReadKeys.removeAll()
        XCTAssertTrue(session.logout())
        XCTAssertTrue(store.dataValues.isEmpty)
        XCTAssertTrue(store.stringValues.isEmpty)
        XCTAssertFalse(makeSession(using: store).isAuthenticated)
        XCTAssertTrue(session.logout(), "Deleting already absent credentials is successful")
    }

    @MainActor
    func testUnreadableNewestCanonicalSlotCannotRestoreSupersededAccount() throws {
        let store = InMemoryCredentialStore()
        let session = makeSession(using: store)
        session.authenticated(authToken: "old-token", userID: 42)
        session.authenticated(authToken: "current-token", userID: 7)
        let snapshot = session.accountSessionSnapshot
        store.unavailableReadKeys.insert(try XCTUnwrap(store.latestCanonicalKey))

        session.updateAuthenticationState()

        XCTAssertEqual(session.accountSessionSnapshot, snapshot)
        XCTAssertEqual(session.userID, 7)
        XCTAssertEqual(AccountSessionAccess(session: session).authorization?.authToken, "current-token")
        XCTAssertFalse(makeSession(using: store).isAuthenticated,
                       "A fresh session must not guess which canonical account is current")
        store.unavailableReadKeys.removeAll()
        XCTAssertEqual(makeSession(using: store).userID, 7)
    }

    @MainActor
    func testUnavailableCanonicalReadsCannotOverwriteDurableLogin() {
        let store = InMemoryCredentialStore()
        let session = makeSession(using: store)
        session.authenticated(authToken: "first-token", userID: 42)
        session.authenticated(authToken: "current-token", userID: 7)
        let records = store.dataValues
        store.unavailableReadKeys.formUnion(CredentialKeys.canonicalSlots)

        session.authenticated(authToken: "requested-token", userID: 99)

        XCTAssertEqual(store.dataValues, records)
        XCTAssertEqual(session.userID, 7)
        XCTAssertEqual(AccountSessionAccess(session: session).authorization?.authToken, "current-token")
        store.unavailableReadKeys.removeAll()
        XCTAssertEqual(makeSession(using: store).userID, 7)
    }

    @MainActor
    func testUnavailableLegacyReadDoesNotDestroyCompleteCredentialPair() {
        let store = InMemoryCredentialStore()
        store.stringValues[CredentialKeys.legacyAuthToken] = "legacy-token"
        store.stringValues[CredentialKeys.legacyUserID] = "42"
        store.unavailableReadKeys.insert(CredentialKeys.legacyAuthToken)
        let values = store.stringValues
        let session = makeSession(using: store)

        XCTAssertFalse(session.isAuthenticated)
        XCTAssertEqual(store.stringValues, values)
        store.unavailableReadKeys.removeAll()
        session.updateAuthenticationState()
        XCTAssertEqual(session.userID, 42)
        XCTAssertEqual(AccountSessionAccess(session: session).authorization?.authToken, "legacy-token")
    }

    @MainActor
    func testUnreadableLegacyMirrorIsDeletedWithoutPresencePrecheck() {
        let store = InMemoryCredentialStore()
        let session = makeSession(using: store)
        session.authenticated(authToken: "current-token", userID: 7)
        store.unavailableReadKeys.insert(CredentialKeys.legacyAuthToken)

        XCTAssertTrue(session.logout())
        XCTAssertTrue(store.stringValues.isEmpty)
        store.unavailableReadKeys.removeAll()
        XCTAssertFalse(makeSession(using: store).isAuthenticated)
    }

    @MainActor
    func testAccountAuthorizationBindsTokenToCurrentSessionGeneration() {
        let store = InMemoryCredentialStore()
        let session = makeSession(using: store)
        session.authenticated(authToken: "first-token", userID: 42)
        let access = AccountSessionAccess(session: session)
        let firstSnapshot = session.accountSessionSnapshot
        let firstCredentialRecordID = access.authorization?.credentialRecordID

        XCTAssertEqual(access.authorization?.accountSession, firstSnapshot)
        XCTAssertEqual(access.authorization?.authToken, "first-token")

        session.authenticated(authToken: "second-token", userID: 42)
        let secondSnapshot = session.accountSessionSnapshot

        XCTAssertNotEqual(firstSnapshot.generation, secondSnapshot.generation)
        XCTAssertNotEqual(
            access.authorization(ifCurrent: secondSnapshot)?.credentialRecordID,
            firstCredentialRecordID
        )
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

    func testKeychainReadStatusDistinguishesUnavailableFromMissing() throws {
        let keychain = CredentialStatusKeychain()
        let store = SessionCredentialStore(keychain: keychain)
        keychain.readStatus = errSecInteractionNotAllowed
        XCTAssertThrowsError(try store.data("fixture").resolved())
        XCTAssertThrowsError(try store.string("fixture").resolved())
        keychain.readStatus = errSecItemNotFound
        XCTAssertNil(try store.data("fixture").resolved())
        XCTAssertNil(try store.string("fixture").resolved())
        keychain.readStatus = errSecSuccess
        keychain.readValue = Data("token".utf8)
        XCTAssertEqual(try store.data("fixture").resolved(), Data("token".utf8))
        XCTAssertEqual(try store.string("fixture").resolved(), "token")
    }

    func testKeychainDeletionRequiresSuccessOrConfirmedAbsence() {
        let keychain = CredentialStatusKeychain()
        let store = SessionCredentialStore(keychain: keychain)
        keychain.deleteStatus = errSecInteractionNotAllowed
        XCTAssertFalse(store.delete("fixture"))
        keychain.deleteStatus = errSecItemNotFound
        XCTAssertTrue(store.delete("fixture"))
        keychain.deleteStatus = errSecSuccess
        XCTAssertTrue(store.delete("fixture"))
    }

    @MainActor
    private func makeSession(using store: InMemoryCredentialStore) -> Session {
        Session(
            credentialStore: store.credentialStore,
            authenticationPresentationDelayNanoseconds: 0
        )
    }
}

enum CredentialKeys {
    static let canonicalPrimary = "accountCredentials.v1.primary"
    static let canonicalSecondary = "accountCredentials.v1.secondary"
    static let canonicalSlots = [canonicalPrimary, canonicalSecondary]
    static let legacyAuthToken = "authToken"
    static let legacyUserID = "userID"
}

struct StoredCredentialFixture: Codable, Equatable {
    let recordID: String?
    let authToken: String
    let userID: Int
    let revision: UInt64
}

final class InMemoryCredentialStore {
    var dataValues = [String: Data]()
    var stringValues = [String: String]()
    var failNextDataWrite = false
    var failingDeleteKeys = Set<String>()
    var unavailableReadKeys = Set<String>()

    var credentialStore: SessionCredentialStore {
        SessionCredentialStore(
            data: { [self] key in
                unavailableReadKeys.contains(key) ? .unavailable : dataValues[key].map(SessionCredentialRead.value) ?? .missing
            },
            string: { [self] key in
                unavailableReadKeys.contains(key) ? .unavailable : stringValues[key].map(SessionCredentialRead.value) ?? .missing
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

private final class CredentialStatusKeychain: KeychainSwift {
    var readStatus: OSStatus = errSecItemNotFound
    var deleteStatus: OSStatus = errSecItemNotFound
    var readValue: Data?

    override func getData(_ key: String, asReference: Bool = false) -> Data? {
        lastResultCode = readStatus
        return readStatus == errSecSuccess ? readValue : nil
    }

    override func delete(_ key: String) -> Bool {
        lastResultCode = deleteStatus
        return deleteStatus == errSecSuccess
    }
}
