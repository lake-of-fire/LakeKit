import Foundation
import KeychainSwift
import Security
import XCTest
@testable import LakeKit

final class SessionCredentialPersistenceTests: XCTestCase {
    @MainActor
    func testNativeKeychainCredentialSlotsPreserveAuthorizationAcrossRestartAndLogout() throws {
        let prefix = "io.manabi.tests.native-credentials.\(UUID().uuidString)."
        let keychain = KeychainSwift(keyPrefix: prefix)
        let ownedKeys = [
            CredentialKeys.canonicalPrimary,
            CredentialKeys.canonicalSecondary,
            CredentialKeys.deprecatedCanonical,
            CredentialKeys.legacyAuthToken,
            CredentialKeys.legacyUserID,
        ]
        // Delete only this test's prefixed keys, including on an assertion/unwrap failure.
        defer {
            for key in ownedKeys {
                let deleted = keychain.delete(key)
                let status = keychain.lastResultCode
                XCTAssertTrue(
                    (deleted && status == errSecSuccess)
                        || (!deleted && status == errSecItemNotFound),
                    "Native Keychain cleanup failed for \(key): OSStatus \(status)"
                )
            }
        }

        func assertOwnedKeysAbsent() {
            for key in ownedKeys {
                let data = keychain.getData(key)
                let status = keychain.lastResultCode
                XCTAssertNil(data, "Unexpected native Keychain value for \(key)")
                XCTAssertEqual(
                    status, errSecItemNotFound,
                    "Native Keychain absence check failed for \(key): OSStatus \(status)"
                )
            }
        }

        func readCredentials(_ key: String) throws -> SessionCredentials {
            let data = keychain.getData(key)
            let status = keychain.lastResultCode
            XCTAssertEqual(
                status, errSecSuccess,
                "Native Keychain read failed for \(key): OSStatus \(status)"
            )
            return try JSONDecoder().decode(
                SessionCredentials.self,
                from: XCTUnwrap(data, "Missing native Keychain record for \(key)")
            )
        }

        assertOwnedKeysAbsent()
        let durableCredentials: SessionCredentials
        do {
            let session = Session(keychain: keychain, authenticationPresentationDelayNanoseconds: 0)
            XCTAssertFalse(session.isAuthenticated)
            XCTAssertNil(AccountSessionAccess(session: session).authorization)

            session.authenticated(authToken: "synthetic-native-first-token", userID: 42)
            let access = AccountSessionAccess(session: session)
            let firstAuthorization = try XCTUnwrap(access.authorization)
            let primary = try readCredentials(CredentialKeys.canonicalPrimary)
            XCTAssertEqual(primary.revision, 1)
            XCTAssertEqual(primary.authToken, "synthetic-native-first-token")
            XCTAssertEqual(primary.userID, 42)
            XCTAssertFalse(primary.recordID.isEmpty)
            XCTAssertEqual(firstAuthorization.credentialRecordID, primary.recordID)
            XCTAssertEqual(firstAuthorization.authToken, primary.authToken)
            XCTAssertEqual(firstAuthorization.accountSession, session.accountSessionSnapshot)

            session.authenticated(authToken: "synthetic-native-second-token", userID: 7)
            let secondAuthorization = try XCTUnwrap(access.authorization)
            durableCredentials = try readCredentials(CredentialKeys.canonicalSecondary)
            XCTAssertEqual(try readCredentials(CredentialKeys.canonicalPrimary), primary)
            XCTAssertEqual(durableCredentials.revision, 2)
            XCTAssertEqual(durableCredentials.authToken, "synthetic-native-second-token")
            XCTAssertEqual(durableCredentials.userID, 7)
            XCTAssertFalse(durableCredentials.recordID.isEmpty)
            XCTAssertNotEqual(durableCredentials.recordID, primary.recordID)
            XCTAssertEqual(secondAuthorization.credentialRecordID, durableCredentials.recordID)
            XCTAssertEqual(secondAuthorization.authToken, durableCredentials.authToken)
            XCTAssertEqual(secondAuthorization.accountSession, session.accountSessionSnapshot)
            XCTAssertEqual(secondAuthorization.accountSession.identity, .authenticated(userID: 7))
            XCTAssertNil(access.authorization(ifCurrent: firstAuthorization.accountSession))

            let mirroredToken = keychain.get(CredentialKeys.legacyAuthToken)
            XCTAssertEqual(keychain.lastResultCode, errSecSuccess)
            XCTAssertEqual(mirroredToken, durableCredentials.authToken)
            let mirroredUserID = keychain.get(CredentialKeys.legacyUserID)
            XCTAssertEqual(keychain.lastResultCode, errSecSuccess)
            XCTAssertEqual(mirroredUserID, String(durableCredentials.userID))
        }

        do {
            // A fresh KeychainSwift instance must recover the same durable identity.
            let restarted = Session(
                keychain: KeychainSwift(keyPrefix: prefix),
                authenticationPresentationDelayNanoseconds: 0
            )
            let access = AccountSessionAccess(session: restarted)
            let authorization = try XCTUnwrap(access.authorization)
            XCTAssertTrue(restarted.isAuthenticated)
            XCTAssertEqual(restarted.userID, durableCredentials.userID)
            XCTAssertEqual(authorization.credentialRecordID, durableCredentials.recordID)
            XCTAssertEqual(authorization.authToken, durableCredentials.authToken)
            XCTAssertEqual(authorization.accountSession, restarted.accountSessionSnapshot)
            XCTAssertEqual(authorization.accountSession.identity, .authenticated(userID: 7))
            XCTAssertEqual(access.authorization(ifCurrent: restarted.accountSessionSnapshot), authorization)

            restarted.updateAuthenticationState()
            XCTAssertEqual(access.authorization, authorization)
            XCTAssertEqual(try readCredentials(CredentialKeys.canonicalSecondary), durableCredentials)

            XCTAssertTrue(restarted.logout(), "Native Keychain logout must succeed")
            XCTAssertFalse(restarted.isAuthenticated)
            XCTAssertEqual(restarted.userID, -1)
            XCTAssertEqual(restarted.accountSessionSnapshot.identity, .signedOut)
            XCTAssertNil(access.authorization)
            XCTAssertNil(access.authorization(ifCurrent: authorization.accountSession))
            assertOwnedKeysAbsent()
        }

        let signedOutRestart = Session(
            keychain: KeychainSwift(keyPrefix: prefix),
            authenticationPresentationDelayNanoseconds: 0
        )
        XCTAssertFalse(signedOutRestart.isAuthenticated)
        XCTAssertEqual(signedOutRestart.userID, -1)
        XCTAssertEqual(signedOutRestart.accountSessionSnapshot.identity, .signedOut)
        XCTAssertNil(AccountSessionAccess(session: signedOutRestart).authorization)
        assertOwnedKeysAbsent()
    }

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
        XCTAssertNotNil(authorization?.credentialRecordID)
        XCTAssertEqual(authorization?.credentialRecordID, store.latestCanonicalRecord?.recordID)
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
    func testCredentialIdentityMatchesDurableRecordSurvivesRestartAndRotatesOnFreshLogin() throws {
        let store = InMemoryCredentialStore()
        let session = makeSession(using: store)
        session.authenticated(authToken: "same-token", userID: 42)
        let access = AccountSessionAccess(session: session)
        let original = try XCTUnwrap(access.authorization)
        let originalID = try XCTUnwrap(original.credentialRecordID)
        XCTAssertFalse(originalID.isEmpty)
        XCTAssertEqual(originalID, store.latestCanonicalRecord?.recordID)
        XCTAssertEqual(
            AccountSessionAccess(session: makeSession(using: store)).authorization?.credentialRecordID,
            originalID
        )
        session.updateAuthenticationState()
        XCTAssertEqual(access.authorization, original)

        session.authenticated(authToken: "same-token", userID: 42)
        let replacement = try XCTUnwrap(access.authorization)
        XCTAssertNotEqual(replacement.credentialRecordID, originalID)
        XCTAssertEqual(replacement.credentialRecordID, store.latestCanonicalRecord?.recordID)
        XCTAssertEqual(replacement.accountSession.generation, original.accountSession.generation &+ 1)
        XCTAssertNil(access.authorization(ifCurrent: original.accountSession))
        XCTAssertTrue(session.logout())
        XCTAssertNil(access.authorization)
    }

    @MainActor
    func testSameTokenDurableReplacementInvalidatesAuthorizationAndPublication() throws {
        let store = InMemoryCredentialStore()
        let session = makeSession(using: store)
        session.authenticated(authToken: "same-token", userID: 42)
        let access = AccountSessionAccess(session: session)
        let original = try XCTUnwrap(access.authorization)
        let replacement = SessionCredentials(authToken: "same-token", userID: 42)
        XCTAssertTrue(SessionCredentialRepository(store: store.credentialStore).persist(replacement))
        session.updateAuthenticationState()

        let current = try XCTUnwrap(access.authorization)
        XCTAssertEqual(current.authToken, original.authToken)
        XCTAssertEqual(current.accountSession.identity, original.accountSession.identity)
        XCTAssertEqual(current.credentialRecordID, replacement.recordID)
        XCTAssertEqual(current.accountSession.generation, original.accountSession.generation &+ 1)
        XCTAssertNotEqual(current, original)
        XCTAssertNil(access.authorization(ifCurrent: original.accountSession))
        var published = false
        XCTAssertFalse(try access.publish(ifCurrent: original.accountSession) { published = true })
        XCTAssertFalse(published)
        XCTAssertTrue(try access.publish(ifCurrent: current.accountSession) { published = true })
        XCTAssertTrue(published)
        session.updateAuthenticationState()
        XCTAssertEqual(access.authorization, current)
    }

    @MainActor
    func testRewritingSameCredentialIdentityDoesNotRotateAuthorizationGeneration() throws {
        let store = InMemoryCredentialStore()
        let session = makeSession(using: store)
        session.authenticated(authToken: "same-token", userID: 42)
        let access = AccountSessionAccess(session: session)
        let original = try XCTUnwrap(access.authorization)
        let identity = try XCTUnwrap(original.credentialRecordID)
        XCTAssertTrue(SessionCredentialRepository(store: store.credentialStore).persist(
            SessionCredentials(authToken: "same-token", userID: 42, recordID: identity)
        ))
        XCTAssertEqual(store.latestCanonicalRecord?.revision, 2)
        session.updateAuthenticationState()
        XCTAssertEqual(access.authorization, original)
    }

    @MainActor
    func testRevisionOverflowDuringIdentityUpgradePreservesLoginWithoutIdentity() throws {
        let store = InMemoryCredentialStore()
        store.dataValues[CredentialKeys.canonicalPrimary] = try JSONEncoder().encode(
            SessionCredentials(authToken: "legacy-token", userID: 42, revision: UInt64.max, recordID: "")
        )
        let session = makeSession(using: store)
        let access = AccountSessionAccess(session: session)
        let original = try XCTUnwrap(access.authorization)
        XCTAssertTrue(session.isAuthenticated)
        XCTAssertEqual(session.userID, 42)
        XCTAssertEqual(original.authToken, "legacy-token")
        XCTAssertNil(original.credentialRecordID)
        XCTAssertNil(store.dataValues[CredentialKeys.canonicalSecondary])
        session.updateAuthenticationState()
        XCTAssertEqual(access.authorization, original)
    }

    @MainActor
    func testLegacyFormsUpgradeOnlyToConfirmedStableIdentity() throws {
        for form in LegacyCredentialForm.allCases {
            let store = InMemoryCredentialStore()
            try seedLegacy(form, into: store)
            let session = makeSession(using: store)
            let authorization = try XCTUnwrap(AccountSessionAccess(session: session).authorization)
            XCTAssertEqual(authorization.authToken, "legacy-token")
            XCTAssertEqual(session.userID, 42)
            let identity = try XCTUnwrap(authorization.credentialRecordID)
            XCTAssertFalse(identity.isEmpty)
            XCTAssertEqual(identity, store.latestCanonicalRecord?.recordID)
            XCTAssertEqual(store.latestCanonicalRecord?.revision, form.isCanonical ? 2 : 1)
            if form.isCanonical {
                XCTAssertNotNil(store.dataValues[CredentialKeys.canonicalPrimary])
                XCTAssertNotNil(store.dataValues[CredentialKeys.canonicalSecondary])
            }
            session.updateAuthenticationState()
            XCTAssertEqual(AccountSessionAccess(session: session).authorization, authorization)
            XCTAssertEqual(
                AccountSessionAccess(session: makeSession(using: store)).authorization?.credentialRecordID,
                identity
            )
        }
    }

    @MainActor
    func testFailedLegacyUpgradesPreserveLoginWithoutInventingIdentity() throws {
        for form in LegacyCredentialForm.allCases {
            let store = InMemoryCredentialStore()
            try seedLegacy(form, into: store)
            store.failDataWrites = true
            let session = makeSession(using: store)
            let access = AccountSessionAccess(session: session)
            let fallback = try XCTUnwrap(access.authorization)
            XCTAssertTrue(session.isAuthenticated)
            XCTAssertEqual(session.userID, 42)
            XCTAssertEqual(fallback.authToken, "legacy-token")
            XCTAssertNil(fallback.credentialRecordID)
            session.updateAuthenticationState()
            XCTAssertEqual(access.authorization, fallback)
            store.failDataWrites = false
            session.updateAuthenticationState()
            let confirmed = try XCTUnwrap(access.authorization)
            XCTAssertNotNil(confirmed.credentialRecordID)
            XCTAssertEqual(confirmed.credentialRecordID, store.latestCanonicalRecord?.recordID)
            XCTAssertEqual(confirmed.accountSession.generation, fallback.accountSession.generation &+ 1)
            XCTAssertNil(access.authorization(ifCurrent: fallback.accountSession))
        }
    }

    @MainActor
    func testUnavailableMigrationReadbackPreservesLoginAndLaterConfirmsIdentity() throws {
        for form in LegacyCredentialForm.allCases {
            let store = InMemoryCredentialStore()
            try seedLegacy(form, into: store)
            store.hideWrittenCanonicalReads = true
            let session = makeSession(using: store)
            let access = AccountSessionAccess(session: session)
            let fallback = try XCTUnwrap(access.authorization)
            XCTAssertTrue(session.isAuthenticated)
            XCTAssertEqual(fallback.authToken, "legacy-token")
            XCTAssertEqual(session.userID, 42)
            XCTAssertNil(fallback.credentialRecordID)
            XCTAssertNotNil(store.latestCanonicalRecord?.recordID)
            store.hiddenReadKeys.removeAll()
            store.hideWrittenCanonicalReads = false
            session.updateAuthenticationState()
            let confirmed = try XCTUnwrap(access.authorization)
            XCTAssertEqual(confirmed.credentialRecordID, store.latestCanonicalRecord?.recordID)
            XCTAssertNotNil(confirmed.credentialRecordID)
            XCTAssertEqual(confirmed.accountSession.generation, fallback.accountSession.generation &+ 1)
            session.updateAuthenticationState()
            XCTAssertEqual(access.authorization, confirmed)
        }
    }

    @MainActor
    func testMismatchedMigrationReadbackDoesNotAuthorizeUnconfirmedIdentity() throws {
        for form in LegacyCredentialForm.allCases {
            let store = InMemoryCredentialStore()
            try seedLegacy(form, into: store)
            store.writtenReadbackOverride = try JSONEncoder().encode(SessionCredentials(
                authToken: "unrelated-token", userID: 7, revision: 100, recordID: "unrelated-record"
            ))
            let session = makeSession(using: store)
            let authorization = try XCTUnwrap(AccountSessionAccess(session: session).authorization)
            XCTAssertTrue(session.isAuthenticated)
            XCTAssertEqual(session.userID, 42)
            XCTAssertEqual(authorization.authToken, "legacy-token")
            XCTAssertNil(authorization.credentialRecordID)
        }
    }

    @MainActor
    func testFreshLoginWithUnavailableReadbackPreservesLoginWithoutInventingIdentity() throws {
        let store = InMemoryCredentialStore()
        let session = makeSession(using: store)
        store.hideWrittenCanonicalReads = true
        session.authenticated(authToken: "fresh-token", userID: 42)
        let access = AccountSessionAccess(session: session)
        let fallback = try XCTUnwrap(access.authorization)
        XCTAssertTrue(session.isAuthenticated)
        XCTAssertEqual(session.userID, 42)
        XCTAssertEqual(fallback.authToken, "fresh-token")
        XCTAssertNil(fallback.credentialRecordID)
        XCTAssertNotNil(store.latestCanonicalRecord?.recordID)
        store.hiddenReadKeys.removeAll()
        store.hideWrittenCanonicalReads = false
        session.updateAuthenticationState()
        XCTAssertEqual(access.authorization?.credentialRecordID, store.latestCanonicalRecord?.recordID)
        XCTAssertEqual(session.accountSessionSnapshot.generation, fallback.accountSession.generation &+ 1)
        XCTAssertNil(access.authorization(ifCurrent: fallback.accountSession))
    }

    @MainActor
    func testFreshLoginWithMismatchedReadbackDoesNotPublishUnconfirmedIdentity() throws {
        let store = InMemoryCredentialStore()
        let session = makeSession(using: store)
        store.writtenReadbackOverride = try JSONEncoder().encode(SessionCredentials(
            authToken: "other-token", userID: 7, revision: 100, recordID: "other-record"
        ))
        session.authenticated(authToken: "fresh-token", userID: 42)
        let authorization = try XCTUnwrap(AccountSessionAccess(session: session).authorization)
        XCTAssertTrue(session.isAuthenticated)
        XCTAssertEqual(session.userID, 42)
        XCTAssertEqual(authorization.authToken, "fresh-token")
        XCTAssertNil(authorization.credentialRecordID)
    }

    func testAuthorizationContextDefaultIdentityAndInjectedIdentityRemainSourceCompatible() throws {
        let snapshot = AccountSessionSnapshot(identity: .authenticated(userID: 42), generation: 1)
        let legacyContext = AccountAuthorizationContext(accountSession: snapshot, authToken: "token")
        XCTAssertNil(legacyContext.credentialRecordID)
        let access = AccountSessionAccess(
            testSnapshotProvider: { snapshot },
            authTokenProvider: { "token" },
            credentialRecordIDProvider: { "confirmed-record" }
        )
        XCTAssertEqual(access.authorization?.credentialRecordID, "confirmed-record")
        XCTAssertNotEqual(access.authorization, legacyContext)
        XCTAssertEqual(Set([legacyContext, try XCTUnwrap(access.authorization)]).count, 2)
    }

    private func seedLegacy(_ form: LegacyCredentialForm, into store: InMemoryCredentialStore) throws {
        if form == .splitPair {
            store.stringValues[CredentialKeys.legacyAuthToken] = "legacy-token"
            store.stringValues[CredentialKeys.legacyUserID] = "42"
            return
        }
        var object: [String: Any] = ["authToken": "legacy-token", "userID": 42, "revision": 1]
        if form == .canonicalEmptyID { object["recordID"] = "" }
        if form == .deprecatedWithID { object["recordID"] = "deprecated-record" }
        store.dataValues[form.isCanonical ? CredentialKeys.canonicalPrimary : CredentialKeys.deprecatedCanonical] =
            try JSONSerialization.data(withJSONObject: object)
    }

    @MainActor
    private func makeSession(using store: InMemoryCredentialStore) -> Session {
        Session(
            credentialStore: store.credentialStore,
            authenticationPresentationDelayNanoseconds: 0
        )
    }
}

private enum LegacyCredentialForm: CaseIterable, Equatable {
    case splitPair, deprecatedMissingID, deprecatedWithID, canonicalMissingID, canonicalEmptyID

    var isCanonical: Bool {
        self == .canonicalMissingID || self == .canonicalEmptyID
    }
}

enum CredentialKeys {
    static let deprecatedCanonical = "accountCredentials.v1"
    static let canonicalPrimary = "accountCredentials.v1.primary"
    static let canonicalSecondary = "accountCredentials.v1.secondary"
    static let canonicalSlots = [canonicalPrimary, canonicalSecondary]
    static let legacyAuthToken = "authToken"
    static let legacyUserID = "userID"
}

struct StoredCredentialFixture: Codable, Equatable {
    let authToken: String
    let userID: Int
    let revision: UInt64
    var recordID: String? = nil
}

final class InMemoryCredentialStore {
    var dataValues = [String: Data]()
    var stringValues = [String: String]()
    var failNextDataWrite = false
    var failDataWrites = false
    var hideWrittenCanonicalReads = false
    var hiddenReadKeys = Set<String>()
    var writtenReadbackOverride: Data?
    var readbackOverrides = [String: Data]()
    var failingDeleteKeys = Set<String>()

    var credentialStore: SessionCredentialStore {
        SessionCredentialStore(
            data: { [self] key in
                guard !hiddenReadKeys.contains(key) else { return nil }
                return readbackOverrides[key] ?? dataValues[key]
            },
            string: { [self] key in
                stringValues[key]
            },
            setData: { [self] data, key in
                if failNextDataWrite || failDataWrites {
                    failNextDataWrite = false
                    // Match KeychainSwift.set's delete-before-add failure behavior.
                    dataValues.removeValue(forKey: key)
                    return false
                }
                dataValues[key] = data
                if hideWrittenCanonicalReads { hiddenReadKeys.insert(key) }
                readbackOverrides[key] = writtenReadbackOverride
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
