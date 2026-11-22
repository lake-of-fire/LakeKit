import XCTest
@testable import LakeKit

final class OnboardingCardSelectionTests: XCTestCase {
    func testSelectedPremiumRemovalReturnsToSurvivingFinalPage() {
        let before = ["video-welcome", "reading-goal", "widgets", "premium"]
        let after = ["video-welcome", "reading-goal", "widgets"]
        let selection = OnboardingCardSelection(selectedID: "premium",
            previousCardIDs: before, cardIDs: after)
        XCTAssertEqual(selection.id, "widgets")
        XCTAssertTrue(selection.isFinished)
        let nextAppearance = OnboardingCardSelection(selectedID: selection.id,
            previousCardIDs: after, cardIDs: after)
        XCTAssertEqual(nextAppearance.id, "widgets", "Reappearance retains the repaired presentation position")
        XCTAssertTrue(nextAppearance.isFinished)
    }

    func testCardRemovalChoosesNearestSurvivingNeighborWithoutSkippingSetup() {
        let before = ["intro", "goal", "widgets", "premium"]
        for (removedID, after, expectedID, expectedFinished) in [
            ("intro", ["goal", "widgets", "premium"], "goal", false),
            ("goal", ["intro", "widgets", "premium"], "intro", false),
            ("widgets", ["intro", "goal", "premium"], "goal", false),
            ("premium", ["intro", "goal"], "goal", true),
        ] {
            let selection = OnboardingCardSelection(selectedID: removedID,
                previousCardIDs: before, cardIDs: after)
            XCTAssertEqual(selection.id, expectedID, removedID)
            XCTAssertEqual(selection.isFinished, expectedFinished, removedID)
        }
    }

    func testCardReorderPreservesSelectionAndRecomputesFinalPage() {
        let first = OnboardingCardSelection(selectedID: "goal",
            previousCardIDs: ["intro", "goal", "premium"], cardIDs: ["premium", "intro", "goal"])
        XCTAssertEqual(first.id, "goal")
        XCTAssertTrue(first.isFinished)
        let next = OnboardingCardSelection(selectedID: first.id,
            previousCardIDs: ["premium", "intro", "goal"], cardIDs: ["goal", "premium", "intro"])
        XCTAssertEqual(next.id, "goal")
        XCTAssertFalse(next.isFinished)
        let appended = OnboardingCardSelection(selectedID: "goal",
            previousCardIDs: ["intro", "goal"], cardIDs: ["intro", "goal", "premium"])
        XCTAssertEqual(appended.id, "goal")
        XCTAssertFalse(appended.isFinished, "An added final card must update finish controls")
    }

    func testEmptyAndReplacementCardListsDoNotFinishOrCarryRetiredSelection() {
        let emptied = OnboardingCardSelection(selectedID: "premium",
            previousCardIDs: ["intro", "premium"], cardIDs: [])
        XCTAssertNil(emptied.id)
        XCTAssertFalse(emptied.isFinished, "An empty list has no completed final page")
        let repopulated = OnboardingCardSelection(selectedID: emptied.id,
            previousCardIDs: [], cardIDs: ["new-intro", "goal"])
        XCTAssertEqual(repopulated.id, "new-intro")
        XCTAssertFalse(repopulated.isFinished)
        let replaced = OnboardingCardSelection(selectedID: "premium",
            previousCardIDs: ["intro", "premium"], cardIDs: ["new-intro", "goal"])
        XCTAssertEqual(replaced.id, "new-intro")
        XCTAssertFalse(replaced.isFinished)
        let replay = OnboardingCardSelection(selectedID: nil,
            previousCardIDs: ["new-intro", "goal"], cardIDs: ["new-intro", "goal"])
        XCTAssertEqual(replay.id, "new-intro", "A fresh replay still starts at its first page")
        XCTAssertFalse(replay.isFinished)
        let only = OnboardingCardSelection(selectedID: nil, previousCardIDs: [], cardIDs: ["intro"])
        XCTAssertEqual(only.id, "intro")
        XCTAssertTrue(only.isFinished)
    }
}
