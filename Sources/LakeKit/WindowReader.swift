//
//  FrameTag.swift
//  Popovers
//
//  Created by A. Zheng (github.com/aheze) on 12/23/21.
//  Copyright © 2022 A. Zheng. All rights reserved.
//

#if os(macOS)
import SwiftUI
import AppKit
//
//@available(OSX 11.0, *)
//public extension View {
//    func wndAccessor(_ act: @escaping (NSWindow?) -> () )
//        -> some View {
//            self.modifier(WndTitleConfigurer(act: act))
//    }
//}
//
//@available(OSX 11.0, *)
//struct WndTitleConfigurer: ViewModifier {
//    let act: (NSWindow?) -> ()
//    
//    @State var window: NSWindow? = nil
//    
//    func body(content: Content) -> some View {
//        content
//            .getWindow($window)
//            .onChange(of: window, perform: act )
//    }
//}
//
//@available(OSX 11.0, *)
//private extension View {
//    func getWindow(_ wnd: Binding<NSWindow?>) -> some View {
//        self.background(WindowAccessor(for: wnd))
//    }
//}
//
//@available(OSX 11.0, *)
//private struct WindowAccessor: NSViewRepresentable {
//    @Binding var window: NSWindow?
//    
//    public func makeNSView(context: Context) -> NSView {
//        let view = NSView()
//        DispatchQueue.main.async {
//            self.window = view.window
//        }
//        return view
//    }
//    
//    public func updateNSView(_ nsView: NSView, context: Context) {}
//}

/*
class WindowViewModel: ObservableObject {
    @Published var window: NSWindow?
}

public struct WindowReader<Content: View>: View {
    /// Your SwiftUI view.
    public let view: (NSWindow?) -> Content

    /// The read window.
    @StateObject var windowViewModel = WindowViewModel()

    /// Reads the `UIWindow` that hosts some SwiftUI content.
    public init(@ViewBuilder view: @escaping (NSWindow?) -> Content) {
        self.view = view
    }

    public var body: some View {
        let _ = Self._printChanges()
        view(windowViewModel.window)
//            .id(windowViewModel.window)
            .background(
                WindowHandlerRepresentable(windowViewModel: windowViewModel)
            )
            .task {
                print("uh win \(windowViewModel.window)")
            }
        
    }

    /// A wrapper view to read the parent window.
    private struct WindowHandlerRepresentable: NSViewRepresentable {
        @ObservedObject var windowViewModel: WindowViewModel

        func makeNSView(context _: Context) -> WindowHandler {
            return WindowHandler(windowViewModel: self.windowViewModel)
        }

        func updateNSView(_: WindowHandler, context _: Context) {}
    }

    private class WindowHandler: NSView {
        var windowViewModel: WindowViewModel

        init(windowViewModel: WindowViewModel) {
            self.windowViewModel = windowViewModel
            super.init(frame: .zero)
            layer?.backgroundColor = .clear
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("Create this view programmatically.")
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()

            let window = self.window
            print("got window \(window)")
            Task { @MainActor in
                /// Set the window.
            print("set window \(window)")
                self.windowViewModel.window = window
            }
        }
    }
}
*/
#endif
