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

    public func updateUIView(_ uiView: UIViewType, context: Context) {
        guard let view = uiView as? MyView else { return }
        view.sideCollapsed = _sideCollapsed
        view.updateSidebarDisplayState()
    }

    class MyView: UIView {
        var sideCollapsed: Binding<Bool>?

        weak private var controller: UISplitViewController?
        
        override func didMoveToWindow() {
            super.didMoveToWindow()
            updateSidebarDisplayState()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            updateSidebarDisplayState()
        }

        func updateSidebarDisplayState() {
            guard let splitViewController = findSplitViewController() else { return }
            controller = splitViewController
            let isSidebarCollapsed = Self.isSidebarCollapsed(in: splitViewController)
            guard sideCollapsed?.wrappedValue != isSidebarCollapsed else { return }
            DispatchQueue.main.async { [weak self] in
                guard self?.sideCollapsed?.wrappedValue != isSidebarCollapsed else { return }
                self?.sideCollapsed?.wrappedValue = isSidebarCollapsed
            }
        }

        private func findSplitViewController() -> UISplitViewController? {
            if let controller, controller.view.window != nil {
                return controller
            }

            var responder: UIResponder? = self
            while let currentResponder = responder {
                if let viewController = currentResponder as? UIViewController,
                   let splitViewController = viewController.splitViewController {
                    return splitViewController
                }
                responder = currentResponder.next
            }

            guard let rootViewController = window?.rootViewController else { return nil }
            return firstSplitViewController(in: rootViewController)
        }

        private func firstSplitViewController(in viewController: UIViewController) -> UISplitViewController? {
            if let splitViewController = viewController as? UISplitViewController {
                return splitViewController
            }
            if let presentedViewController = viewController.presentedViewController,
               let splitViewController = firstSplitViewController(in: presentedViewController) {
                return splitViewController
            }
            for childViewController in viewController.children {
                if let splitViewController = firstSplitViewController(in: childViewController) {
                    return splitViewController
                }
            }
            return nil
        }

        private static func isSidebarCollapsed(in splitViewController: UISplitViewController) -> Bool {
            switch splitViewController.displayMode {
            case .secondaryOnly:
                return true
            case .oneBesideSecondary,
                 .oneOverSecondary,
                 .twoBesideSecondary,
                 .twoOverSecondary,
                 .twoDisplaceSecondary:
                return false
            case .automatic:
                return splitViewController.isCollapsed
            @unknown default:
                return splitViewController.isCollapsed
            }
        }
    }
}

#endif
