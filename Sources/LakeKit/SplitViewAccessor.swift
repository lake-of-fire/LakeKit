import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

#if os(macOS)
/// See: https://github.com/Asperi-Demo/4SwiftUI/blob/master/Answers/Get_sidebar_isCollapsed.md
public struct SplitViewAccessor: NSViewRepresentable {
    @Binding var sideCollapsed: Bool

    public init(sideCollapsed: Binding<Bool>) {
        _sideCollapsed = sideCollapsed
    }
    
    public func makeNSView(context: Context) -> some NSView {
        let view = MyView()
        view.sideCollapsed = _sideCollapsed
        return view
    }

    public func updateNSView(_ nsView: NSViewType, context: Context) {
    }

    class MyView: NSView {
        var sideCollapsed: Binding<Bool>?

        weak private var controller: NSSplitViewController?
        private var observer: Any?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            var sview = self.superview
            while sview != nil, !sview!.isKind(of: NSSplitView.self) {
                sview = sview?.superview
            }
            guard let sview = sview as? NSSplitView else { return }
            controller = sview.delegate as? NSSplitViewController
            if let sideBar = controller?.splitViewItems.first {
                observer = sideBar.observe(\.isCollapsed, options: [.new]) { [weak self] _, change in
                    if let value = change.newValue {
                        self?.sideCollapsed?.wrappedValue = value
                    }
                }
                sideCollapsed?.wrappedValue = sideBar.isCollapsed
            }
        }
    }
}
#else
/// See: https://github.com/Asperi-Demo/4SwiftUI/blob/master/Answers/Get_sidebar_isCollapsed.md
public struct SplitViewAccessor: UIViewRepresentable {
    @Binding var sideCollapsed: Bool

    public init(sideCollapsed: Binding<Bool>) {
        _sideCollapsed = sideCollapsed
    }
    
    public func makeUIView(context: Context) -> some UIView {
        let view = MyView()
        view.sideCollapsed = _sideCollapsed
        return view
    }

    public func updateUIView(_ nsView: UIViewType, context: Context) {
    }

    class MyView: UIView {
        var sideCollapsed: Binding<Bool>?

        weak private var controller: UISplitViewController?
        private var observer: Any?
        
        override func didMoveToWindow() {
            super.didMoveToWindow()
            var sview = self.superview
            // FIXME this doesn't find the controller
            controller = sview?.window?.rootViewController as? UISplitViewController
            if let controller = controller {
                observer = controller.observe(\.isCollapsed, options: [.new]) { [weak self] _, change in
                    if let value = change.newValue {
                        self?.sideCollapsed?.wrappedValue = value
                    }
                }
                sideCollapsed?.wrappedValue = controller.isCollapsed
            }
        }
    }
}

#endif
