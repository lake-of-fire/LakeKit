import XCTest
@testable import LakeKit

final class FitWidthSegmentedPickerTests: XCTestCase {
    private enum Option: Hashable {
        case word
        case sentence
        case paragraph
    }

    func testChangedSelectionAndReselectionRemainDistinct() {
        let options: [Option] = [.word, .sentence, .paragraph]
        XCTAssertEqual(
            fitWidthSegmentedPickerAction(
                options: options,
                disabledOptions: [],
                index: 1,
                interaction: .selectionChanged
            ),
            .select(.sentence)
        )
        XCTAssertEqual(
            fitWidthSegmentedPickerAction(
                options: options,
                disabledOptions: [],
                index: 1,
                interaction: .selectionReselected
            ),
            .reselect(.sentence)
        )
    }

    func testDisabledAndOutOfBoundsInteractionsAreIgnored() {
        let options: [Option] = [.word, .sentence, .paragraph]
        XCTAssertEqual(
            fitWidthSegmentedPickerAction(
                options: options,
                disabledOptions: [.paragraph],
                index: 2,
                interaction: .selectionChanged
            ),
            .ignore
        )
        XCTAssertEqual(
            fitWidthSegmentedPickerAction(
                options: options,
                disabledOptions: [],
                index: 9,
                interaction: .selectionChanged
            ),
            .ignore
        )
    }
}
