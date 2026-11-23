#if os(macOS)
import AppKit
import SwiftUI
import XCTest
@testable import LakeKit

@MainActor
final class ShareSheetAppKitTests: XCTestCase {
    typealias Item = ActivityItem<[URL]>
    final class RequestBox<Request> {
        var value: Request?
        var binding: Binding<Request?> { Binding(get: { self.value }, set: { self.value = $0 }) }
    }

    func testActivityIdentityIsStableForCopiesButDistinctForNewRequests() async {
        let first = request(), copied = first, next = request()
        XCTAssertEqual(first.presentationID, copied.presentationID)
        XCTAssertNotEqual(first.presentationID, next.presentationID)
    }

    func testLiveBindingUpdatePresentsAndClearsOnce() async {
        let box = RequestBox<Item>()
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
        let box = RequestBox<Item>()
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
        let box = RequestBox<Item>()
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
        let box = RequestBox<Item>()
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
        let box = RequestBox<Item>()
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
        let box = RequestBox<Item>()
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
        let box = RequestBox<Item>()
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

    func testReentrantPayloadProjectionCannotOverwriteSuccessorPicker() async {
        typealias Request = ActivityItem<[ReentrantShareItem]>
        typealias SourceView = ShareSheet<[ReentrantShareItem]>.SourceView
        let box = RequestBox<Request>()
        let successor = Request(data: [ReentrantShareItem()])
        var shown: [NSSharingServicePicker] = []
        var view: SourceView?
        let reentrant = ReentrantShareItem {
            box.value = successor
            if let view { view.item = box.binding }
        }
        box.value = Request(data: [reentrant])
        let sourceView = SourceView(item: box.binding) { picker, _ in shown.append(picker) }
        view = sourceView
        let window = window(sourceView)
        defer {
            sourceView.tearDown()
            view = nil
            window.close()
        }

        await drain()
        XCTAssertEqual(shown.count, 1)
        XCTAssertEqual(box.value?.presentationID, successor.presentationID)
        // That single picker must own the successor, not the retired request.
        if let picker = shown.first {
            sourceView.sharingServicePicker(picker, didChoose: nil)
            XCTAssertNil(box.value)
        }
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
}
private struct ReentrantShareItem: Shareable {
    var onRead: () -> Void = {}
    var pathExtension: String { "txt" }
    var itemProvider: NSItemProvider? { nil }
    var sharingItem: Any {
        onRead()
        return "share"
    }
}
#endif
