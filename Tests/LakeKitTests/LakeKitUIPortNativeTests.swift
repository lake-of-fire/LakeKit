#if os(macOS)
import AppKit
import SwiftUI
import XCTest
@testable import LakeKit

@MainActor
final class LakeKitUIPortNativeTests: XCTestCase {
    typealias Item = ActivityItem<[URL]>
    final class RequestBox {
        var value: Item?
        var binding: Binding<Item?> { Binding(get: { self.value }, set: { self.value = $0 }) }
    }
    final class SelectionBox {
        var value = "one"
        var selected: [String] = []
        var reselected: [String] = []
        var binding: Binding<String> { Binding(get: { self.value }, set: { self.value = $0 }) }
    }

    func testActivityIdentityIsStableForCopiesButDistinctForNewRequests() async {
        let first = request(), copied = first, next = request()
        XCTAssertEqual(first.presentationID, copied.presentationID)
        XCTAssertNotEqual(first.presentationID, next.presentationID)
    }

    func testLiveBindingUpdatePresentsAndClearsOnce() async {
        let box = RequestBox()
        var shown: [NSSharingServicePicker] = []
        let view = ShareSheet<[URL]>.SourceView(item: box.binding) { picker, _ in shown.append(picker) }
        let window = window(view)
        defer { view.tearDown(); window.close() }
        box.value = request()
        view.item = box.binding
        await drain()
        XCTAssertEqual(shown.count, 1)
        view.item = box.binding
        await drain()
        XCTAssertEqual(shown.count, 1)
        box.value = nil
        view.item = box.binding
        await drain()
        XCTAssertNil(box.value)
        XCTAssertEqual(shown.count, 1)
    }

    func testInitialRequestWaitsUntilAttached() async {
        let box = RequestBox()
        box.value = request()
        var count = 0
        let view = ShareSheet<[URL]>.SourceView(item: box.binding) { _, _ in count += 1 }
        view.updateItem()
        await drain()
        XCTAssertEqual(count, 0)
        let window = window(view)
        defer { view.tearDown(); window.close() }
        await drain()
        XCTAssertEqual(count, 1)
    }

    func testClearedRequestCannotBeShownByQueuedPresentation() async {
        let box = RequestBox()
        box.value = request()
        var count = 0
        let view = ShareSheet<[URL]>.SourceView(item: box.binding) { _, _ in count += 1 }
        let window = window(view)
        defer { view.tearDown(); window.close() }
        box.value = nil // Deliberately no representable update before the queued show.
        await drain()
        XCTAssertEqual(count, 0)
    }

    func testOldCompletionCannotClearNewBindingBeforeViewUpdate() async throws {
        let box = RequestBox()
        box.value = request()
        var shown: [NSSharingServicePicker] = []
        let view = ShareSheet<[URL]>.SourceView(item: box.binding) { picker, _ in shown.append(picker) }
        let window = window(view)
        defer { view.tearDown(); window.close() }
        await drain()
        let old = try XCTUnwrap(shown.first)
        let next = request()
        box.value = next
        view.sharingServicePicker(old, didChoose: nil)
        await drain()
        XCTAssertEqual(box.value?.presentationID, next.presentationID)
        XCTAssertEqual(shown.count, 2)
        view.sharingServicePicker(old, didChoose: nil)
        XCTAssertEqual(box.value?.presentationID, next.presentationID)
    }

    func testMatchingNativeCompletionClearsCurrentRequest() async throws {
        let box = RequestBox()
        box.value = request()
        var shown: NSSharingServicePicker?
        let view = ShareSheet<[URL]>.SourceView(item: box.binding) { picker, _ in shown = picker }
        let window = window(view)
        defer { view.tearDown(); window.close() }
        await drain()
        view.sharingServicePicker(try XCTUnwrap(shown), didChoose: nil)
        XCTAssertNil(box.value)
    }

    func testTeardownInvalidatesQueuedPresentationWithoutClearingRequest() async {
        let box = RequestBox()
        let original = request()
        box.value = original
        var count = 0
        let view = ShareSheet<[URL]>.SourceView(item: box.binding) { _, _ in count += 1 }
        let window = window(view)
        defer { window.close() }
        view.tearDown()
        await drain()
        XCTAssertEqual(count, 0)
        XCTAssertEqual(box.value?.presentationID, original.presentationID)
    }

    func testDetachReattachCanPresentSameRequestAgain() async {
        let box = RequestBox()
        box.value = request()
        var count = 0
        let view = ShareSheet<[URL]>.SourceView(item: box.binding) { _, _ in count += 1 }
        let window = window(view)
        defer { view.tearDown(); window.close() }
        await drain()
        XCTAssertEqual(count, 1)
        window.contentView = NSView()
        window.contentView = view
        await drain()
        XCTAssertEqual(count, 2)
    }

    func testNativePickerOnSelectDoesNotForceBindingAndReselectUsesNativeHistory() async throws {
        let box = SelectionBox()
        let host = NSHostingView(rootView: FitWidthSegmentedPicker(["one", "two"], selection: box.binding,
            onSelect: { box.selected.append($0) }, onReselect: { box.reselected.append($0) }))
        let window = window(host)
        defer { window.close() }
        host.layoutSubtreeIfNeeded()
        await drain()
        let control = try XCTUnwrap(findControl(host))
        control.selectedSegment = 1
        control.sendAction(control.action, to: control.target)
        XCTAssertEqual(box.selected, ["two"])
        XCTAssertEqual(box.value, "one")
        control.sendAction(control.action, to: control.target)
        XCTAssertEqual(box.selected, ["two"])
        XCTAssertEqual(box.reselected, ["two"])
    }

    func testNativePickerDefaultBindingAndDisabledOptions() async throws {
        let box = SelectionBox()
        let host = NSHostingView(rootView: FitWidthSegmentedPicker(["one", "two", "three"],
            selection: box.binding, disabledOptions: ["three"], accessibilityIdentifier: "port-picker"))
        let window = window(host)
        defer { window.close() }
        host.layoutSubtreeIfNeeded()
        await drain()
        let control = try XCTUnwrap(findControl(host))
        XCTAssertFalse(control.isEnabled(forSegment: 2))
        XCTAssertEqual(control.accessibilityIdentifier(), "port-picker")
        control.selectedSegment = 1
        control.sendAction(control.action, to: control.target)
        XCTAssertEqual(box.value, "two")
        control.selectedSegment = 2 // Even a programmatic invalid event must be rejected.
        control.sendAction(control.action, to: control.target)
        XCTAssertEqual(box.value, "two")
    }

    private func request() -> Item { Item(data: [URL(string: "https://example.invalid/share")!]) }
    private func window(_ content: NSView) -> NSWindow {
        _ = NSApplication.shared
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 320, height: 80),
                              styleMask: .borderless, backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = content
        return window
    }
    private func drain() async {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async { continuation.resume() }
        }
    }
    private func findControl(_ view: NSView) -> NSSegmentedControl? {
        if let control = view as? NSSegmentedControl { return control }
        for child in view.subviews { if let control = findControl(child) { return control } }
        return nil
    }
}
#endif
