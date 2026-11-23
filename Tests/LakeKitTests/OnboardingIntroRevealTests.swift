import XCTest
@testable import LakeKit

final class OnboardingIntroRevealTests: XCTestCase {
    func testReduceMotionKeepsIntroGatedUntilReadiness() {
        var reveal = OnboardingIntroRevealState()

        XCTAssertFalse(reveal.revealImmediatelyIfNeeded(isReady: false, reduceMotion: true, featureCount: 3))
        XCTAssertEqual(reveal, OnboardingIntroRevealState())

        XCTAssertTrue(reveal.revealImmediatelyIfNeeded(isReady: true, reduceMotion: true, featureCount: 3))
        XCTAssertEqual(reveal.visibleFeatureCount, 3)
        XCTAssertTrue(reveal.isHeaderVisible)
        XCTAssertTrue(reveal.isDescriptionVisible)
        XCTAssertTrue(reveal.isPrimaryButtonVisible)
        XCTAssertFalse(reveal.isPrimaryButtonGlowing)
        XCTAssertEqual(reveal.titleShineCount, 0)
    }

    func testReadyIntroWithoutFeaturesShowsPrimaryActionInEitherMotionMode() {
        for reduceMotion in [false, true] {
            var reveal = OnboardingIntroRevealState()

            XCTAssertFalse(reveal.revealImmediatelyIfNeeded(isReady: false, reduceMotion: reduceMotion, featureCount: 0))
            XCTAssertTrue(reveal.revealImmediatelyIfNeeded(isReady: true, reduceMotion: reduceMotion, featureCount: 0))
            XCTAssertEqual(reveal.visibleFeatureCount, 0)
            XCTAssertTrue(reveal.isHeaderVisible)
            XCTAssertTrue(reveal.isDescriptionVisible)
            XCTAssertTrue(reveal.isPrimaryButtonVisible)
            XCTAssertNil(reveal.animationID)
        }
    }

    func testEnablingReduceMotionRetiresInFlightAnimationAndTurningItOffKeepsReveal() {
        var reveal = OnboardingIntroRevealState()
        XCTAssertFalse(reveal.revealImmediatelyIfNeeded(isReady: true, reduceMotion: false, featureCount: 3))
        let animated = reveal.beginAnimation()
        reveal.visibleFeatureCount = 1
        reveal.titleShineCount = 1
        reveal.isPrimaryButtonGlowing = true

        XCTAssertEqual(reveal.animationID, animated)
        XCTAssertTrue(reveal.revealImmediatelyIfNeeded(isReady: true, reduceMotion: true, featureCount: 3))
        XCTAssertNil(reveal.animationID)
        XCTAssertTrue(reveal.hasPlayedAnimation)
        XCTAssertEqual(reveal.visibleFeatureCount, 3)
        XCTAssertTrue(reveal.isPrimaryButtonVisible)
        XCTAssertFalse(reveal.isPrimaryButtonGlowing)
        XCTAssertEqual(reveal.titleShineCount, 0)

        let settled = reveal
        XCTAssertFalse(reveal.revealImmediatelyIfNeeded(isReady: true, reduceMotion: false, featureCount: 3))
        XCTAssertEqual(reveal, settled)
    }

    func testRetiredAnimationCannotOwnNextCardReveal() {
        var reveal = OnboardingIntroRevealState()
        let first = reveal.beginAnimation()
        reveal.retireAnimation()
        XCTAssertNil(reveal.animationID)

        let next = reveal.beginAnimation()
        XCTAssertNotEqual(next, first)
        XCTAssertEqual(reveal.animationID, next)
    }
}
