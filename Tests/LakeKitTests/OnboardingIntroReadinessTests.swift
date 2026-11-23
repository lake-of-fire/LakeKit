import Foundation
import XCTest
@testable import LakeKit

final class OnboardingIntroReadinessTests: XCTestCase {
    private let introID = "video-welcome"

    func testWrongNotificationOrSenderDoesNotReleaseCurrentIntro() {
        let presentation = UUID()
        var gate = OnboardingIntroReadinessGate()
        let wrongNotifications = [
            Notification(name: .init("UnrelatedNotification"), object: presentation),
            readyNotification(from: nil),
            readyNotification(from: UUID()),
            readyNotification(from: presentation.uuidString),
        ]

        for notification in wrongNotifications {
            XCTAssertFalse(gate.receive(notification, presentationID: presentation, introCardID: introID))
        }
        XCTAssertFalse(gate.isReleased(presentationID: presentation, introCardID: introID))

        XCTAssertTrue(gate.receive(readyNotification(from: presentation), presentationID: presentation, introCardID: introID))
        XCTAssertTrue(gate.isReleased(presentationID: presentation, introCardID: introID))
    }

    func testMatchingNotificationOnlyReleasesCurrentIntroOnce() {
        let presentation = UUID()
        let notification = readyNotification(from: presentation)
        var gate = OnboardingIntroReadinessGate()

        XCTAssertFalse(gate.receive(notification, presentationID: nil, introCardID: introID))
        XCTAssertFalse(gate.receive(notification, presentationID: presentation, introCardID: nil))
        XCTAssertTrue(gate.receive(notification, presentationID: presentation, introCardID: introID))
        XCTAssertFalse(gate.receive(notification, presentationID: presentation, introCardID: introID))
    }

    func testReturningToIntroRequiresReadinessAndKeepsAnEarlyCurrentResult() {
        let presentation = UUID()
        let notification = readyNotification(from: presentation)
        var gate = OnboardingIntroReadinessGate()
        XCTAssertTrue(gate.receive(notification, presentationID: presentation, introCardID: introID))

        gate.retainReadiness(presentationID: presentation, introCardID: nil)
        XCTAssertFalse(gate.isReleased(presentationID: presentation, introCardID: introID))

        // The active card can publish before SwiftUI invokes its selection observer.
        XCTAssertTrue(gate.receive(notification, presentationID: presentation, introCardID: introID))
        gate.retainReadiness(presentationID: presentation, introCardID: introID)
        XCTAssertTrue(gate.isReleased(presentationID: presentation, introCardID: introID))
        XCTAssertFalse(gate.receive(notification, presentationID: presentation, introCardID: introID))
    }

    func testReadinessFromOldPresentationCannotReleaseReplacement() {
        let original = UUID()
        let replacement = UUID()
        let oldNotification = readyNotification(from: original)
        var gate = OnboardingIntroReadinessGate()
        XCTAssertTrue(gate.receive(oldNotification, presentationID: original, introCardID: introID))

        XCTAssertFalse(gate.isReleased(presentationID: replacement, introCardID: introID))
        XCTAssertFalse(gate.receive(oldNotification, presentationID: replacement, introCardID: introID))
        XCTAssertTrue(gate.receive(readyNotification(from: replacement), presentationID: replacement, introCardID: introID))
        XCTAssertTrue(gate.isReleased(presentationID: replacement, introCardID: introID))
    }

    private func readyNotification(from sender: Any?) -> Notification {
        Notification(name: OnboardingIntroReadinessNotification.name, object: sender)
    }
}
