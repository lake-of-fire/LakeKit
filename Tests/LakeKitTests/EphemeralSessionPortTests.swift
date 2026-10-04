#if DEBUG
import Foundation
import XCTest
@testable import LakeKit

@MainActor
final class EphemeralSessionPortTests: XCTestCase {
    func testNewFixtureStartsSignedOutWithoutAuthorization() {
        let session = Session.ephemeralForTesting()
        XCTAssertEqual(session.userID, -1)
        XCTAssertEqual(session.fastUserID, -1)
        XCTAssertFalse(session.isAuthenticated)
        XCTAssertEqual(session.accountSessionSnapshot.identity, .signedOut)
        XCTAssertNil(AccountSessionAccess(session: session).authorization)
    }

    func testSeparateFixturesDoNotShareStorageOrPublicationBoundaries() {
        let first = Session.ephemeralForTesting()
        let second = Session.ephemeralForTesting()
        let firstAccess = AccountSessionAccess(session: first)
        let secondAccess = AccountSessionAccess(session: second)
        XCTAssertNotEqual(firstAccess.boundaryID, secondAccess.boundaryID)
        first.authenticated(authToken: "SYNTHETIC_FIRST_TOKEN", userID: 11)
        XCTAssertEqual(firstAccess.authorization?.authToken, "SYNTHETIC_FIRST_TOKEN")
        XCTAssertFalse(second.isAuthenticated)
        XCTAssertNil(secondAccess.authorization)
        second.authenticated(authToken: "SYNTHETIC_SECOND_TOKEN", userID: 22)
        XCTAssertEqual(first.userID, 11)
        XCTAssertEqual(second.userID, 22)
        XCTAssertTrue(first.logout())
        XCTAssertTrue(second.isAuthenticated)
        XCTAssertEqual(secondAccess.authorization?.authToken, "SYNTHETIC_SECOND_TOKEN")
    }

    func testCredentialRefreshUsesRealRepositoryWithoutChangingStableGeneration() {
        let session = Session.ephemeralForTesting()
        session.authenticated(authToken: "SYNTHETIC_TOKEN", userID: 11)
        let expected = session.accountSessionSnapshot
        session.updateAuthenticationState()
        XCTAssertEqual(session.accountSessionSnapshot, expected)
        XCTAssertEqual(session.observedAccountSessionSnapshot, expected)
        XCTAssertEqual(AccountSessionAccess(session: session).authorization?.authToken, "SYNTHETIC_TOKEN")
    }

    func testSameAccountTokenReplacementInvalidatesCapturedAuthorization() throws {
        let session = Session.ephemeralForTesting()
        let access = AccountSessionAccess(session: session)
        session.authenticated(authToken: "SYNTHETIC_OLD", userID: 11)
        let old = session.accountSessionSnapshot
        session.authenticated(authToken: "SYNTHETIC_NEW", userID: 11)
        XCTAssertNotEqual(session.accountSessionSnapshot, old)
        XCTAssertNil(access.authorization(ifCurrent: old))
        var published = false
        XCTAssertFalse(try access.publish(ifCurrent: old) { published = true })
        XCTAssertFalse(published)
        XCTAssertEqual(access.authorization?.authToken, "SYNTHETIC_NEW")
    }

    func testLogoutRemovesFixtureCredentialsAndRejectsOldPublication() throws {
        let session = Session.ephemeralForTesting()
        let access = AccountSessionAccess(session: session)
        session.authenticated(authToken: "SYNTHETIC_TOKEN", userID: 11)
        let old = session.accountSessionSnapshot
        XCTAssertTrue(session.logout())
        session.updateAuthenticationState()
        XCTAssertFalse(session.isAuthenticated)
        XCTAssertEqual(session.accountSessionSnapshot.identity, .signedOut)
        XCTAssertNil(access.authorization)
        XCTAssertFalse(try access.publish(ifCurrent: old) { XCTFail("Stale publication") })
    }

    func testInvalidReplacementPreservesPreviouslyStoredCredentialPair() {
        let session = Session.ephemeralForTesting()
        session.authenticated(authToken: "SYNTHETIC_DURABLE", userID: 11)
        session.authenticated(authToken: "", userID: 22)
        XCTAssertEqual(session.userID, 11)
        XCTAssertTrue(session.isAuthenticated)
        XCTAssertEqual(AccountSessionAccess(session: session).authorization?.authToken, "SYNTHETIC_DURABLE")
        session.updateAuthenticationState()
        XCTAssertEqual(session.userID, 11)
    }

    func testAlreadyAuthenticatedFixtureNeedsNoPresentation() async throws {
        let session = Session.ephemeralForTesting(authenticationPresentationDelayNanoseconds: 0)
        session.authenticated(authToken: "SYNTHETIC_TOKEN", userID: 11)
        try await session.requireAuthentication()
        XCTAssertFalse(session.isPresentingWebAuthentication)
    }

    func testPreCancelledAuthenticationRequestDoesNotPresentOrLeakWaiter() async {
        let session = Session.ephemeralForTesting(authenticationPresentationDelayNanoseconds: 0)
        let task = Task { @MainActor in
            withUnsafeCurrentTask { $0?.cancel() }
            do {
                try await session.requireAuthentication()
                return false
            } catch is CancellationError { return true }
            catch { return false }
        }
        let cancelled = await task.value
        XCTAssertTrue(cancelled)
        XCTAssertFalse(session.isPresentingWebAuthentication)
        XCTAssertFalse(session.isAuthenticated)
    }
}
#endif
