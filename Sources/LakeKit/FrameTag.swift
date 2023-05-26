//
//  FrameTag.swift
//  Popovers
//
//  Created by A. Zheng (github.com/aheze) on 12/23/21.
//  Copyright © 2022 A. Zheng. All rights reserved.
//

#if os(macOS)
// Forked from https://github.com/aheze/Popovers/blob/54728a9ca199ffbffe444d5b04a9354f6a02da7c/Sources/SwiftUI/FrameTag.swift#L81
import SwiftUI
import AppKit
import PureSwiftUI

/// Store a view's frame for later use.
struct FrameTagModifier: ViewModifier {
    /// The name of the frame.
    let tag: AnyHashable
    @State var frame = CGRect.zero
    @State private var window: NSWindow? = nil

    func body(content: Content) -> some View {
        WindowReader { window in
            content
                .geometryReader { geometry in
                    if let window = window {
                        self.frame = geometry.frame(in: .local)
                        window.save(self.frame, for: tag)
                    }
                }
                .task {
                    Task { @MainActor in
                        self.window = window
                    }
                }
        }
        .onChange(of: window) { window in
            if let window = window {
                window.save(frame, for: tag)
            }
        }
    }
}

public extension View {
    /**
     Tag a view and store its frame. Access using `Popovers.frameTagged(_:)`.

     You can use this for supplying source frames or excluded frames. **Do not** use it anywhere else, due to State re-rendering issues.

     - parameter tag: The tag for the frame
     */
    func frameTag(_ tag: AnyHashable) -> some View {
        return modifier(FrameTagModifier(tag: tag))
    }
}

public extension NSResponder {
    /**
     Get the saved frame of a frame-tagged view inside this window. You must first set the frame using `.frameTag(_:)`.
     - parameter tag: The tag that you used for the frame.
     - Returns: The frame of a frame-tagged view, or `nil` if no view with the tag exists.
     */
    func frameTagged(_ tag: AnyHashable) -> CGRect {
        return windowTagModel.frame(tagged: tag)
    }

    /// Save a frame in this window's `frameTags`.
    internal func save(_ frame: CGRect, for tag: AnyHashable) {
        windowTagModel.frameTags[tag] = frame
    }
}

public extension Optional where Wrapped: NSResponder {
    /**
     Get the saved frame of a frame-tagged view inside this window. You must first set the frame using `.frameTag(_:)`. This is a convenience overload for optional `NSResponder`s.
     - parameter tag: The tag that you used for the frame.
     - Returns: The frame of a frame-tagged view, or `nil` if no view with the tag exists.
     */
    func frameTagged(_ tag: AnyHashable) -> CGRect {
        if let responder = self {
            return responder.frameTagged(tag)
        }
        return .zero
    }
}

/**
 Popovers supports multiple windows (iOS) by associating each `WindowTagModel` with a window.
 */

/// A map of `WindowTagModel`s scoped to each window.
class WindowTagModels {
    /// The singleton `WindowTagModels` instance.
    static let shared = WindowTagModels()

    /**
     Aggregates the collection of models applicable to each `NSWindow` in the application.

     `NSWindow` references are weakly retained to avoid us leaking application scenes that have been disposed of by iOS,
     e.g. when dismissed from the multitasking UI or explicitly closed by the app.
     */
    private var windowModels = [Weak<NSWindow>: WindowTagModel]()

    private init() {
        /// Enforcing singleton by marking `init` as private.
    }

    /**
     Retrieves the `WindowTagModel` associated with the given `UIWindow`.

     When a `WindowTagModel` already exists for the given `UIWindow`, the same reference will be returned by this function.
     Otherwise, a new model is created and associated with the window.

     - parameter window: The `UIWindow` whose `WindowTagModel` is being requested, e.g. to present a popover.
     - Returns: The `WindowTagModel` used to model the visible popovers for the given window.
     */
    func windowTagModel(for window: NSWindow) -> WindowTagModel {
        /**
         Continually remove entries that refer to `UIWindow`s that are no longer about.
         The view hierarchies have already been dismantled - this is just for our own book keeping.
         */
        pruneDeallocatedWindowModels()

        if let existingModel = existingWindowTagModel(for: window) {
            return existingModel
        } else {
            return prepareAndRetainModel(for: window)
        }
    }

    private func pruneDeallocatedWindowModels() {
        let keysToRemove = windowModels.keys.filter(\.isPointeeDeallocated)
        for key in keysToRemove {
            windowModels[key] = nil
        }
    }

    /// Get an existing popover model for this window if it exists.
    private func existingWindowTagModel(for window: NSWindow) -> WindowTagModel? {
        return windowModels.first(where: { holder, _ in holder.pointee === window })?.value
    }

    private func prepareAndRetainModel(for window: NSWindow) -> WindowTagModel {
        let newModel = WindowTagModel()
        let weakWindowReference = Weak(pointee: window)
        windowModels[weakWindowReference] = newModel

        return newModel
    }

    /// Container type to enable storage of an object type without incrementing its retain count.
    private class Weak<T>: NSObject where T: AnyObject {
        private(set) weak var pointee: T?

        var isPointeeDeallocated: Bool {
            pointee == nil
        }

        init(pointee: T) {
            self.pointee = pointee
        }
    }
}

extension NSResponder {
    /**
     The `WindowTagModel` in the current responder chain.

     Each responder chain hosts a single `WindowTagModel` at the window level.
     Each scene containing a separate window will contain its own `WindowTagModel`, scoping the layout code to each window.

     - Important: Attempting to request the `WindowTagModel` for a responder not present in the chain is programmer error.
     */
    var windowTagModel: WindowTagModel {
        /// If we're a view, continue to walk up the responder chain until we hit the root view.
        if let view = self as? NSView, let superview = view.superview {
            return superview.windowTagModel
        }

        /// If we're a window, we define the scoping for the model - access it.
        if let window = self as? NSWindow {
            return WindowTagModels.shared.windowTagModel(for: window)
        }

        /// If we're a view controller, begin walking the responder chain up to the root view.
        if let viewController = self as? NSViewController {
            return viewController.view.windowTagModel
        }

        print("[Popovers] - No `WindowTagModel` present in responder chain (\(self)) - has the source view been installed into a window? Please file a bug report (https://github.com/aheze/Popovers/issues).")

        return WindowTagModel()
    }
}

/// For passing the hosting window into the environment.
extension EnvironmentValues {
    /// Designates the `NSWindow` hosting the views within the current environment.
    var window: NSWindow? {
        get {
            self[WindowEnvironmentKey.self]
        }
        set {
            self[WindowEnvironmentKey.self] = newValue
        }
    }

    private struct WindowEnvironmentKey: EnvironmentKey {
        typealias Value = NSWindow?

        static var defaultValue: NSWindow? = nil
    }
}

class WindowTagModel: ObservableObject {
    /// Store the frames of views (for excluding popover dismissal or source frames).
    @Published var frameTags: [AnyHashable: CGRect] = [:]

    /// Access this with `UIResponder.frameTagged(_:)` if inside a `WindowReader`, or `Popover.Context.frameTagged(_:)` if inside a `PopoverReader.`
    func frame(tagged tag: AnyHashable) -> CGRect {
        let frame = frameTags[tag]
        return frame ?? .zero
    }
}
#endif
