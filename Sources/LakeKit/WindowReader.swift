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
        view(windowViewModel.window)
//            .id(windowViewModel.window)
            .background(
                WindowHandlerRepresentable(windowViewModel: windowViewModel)
            )
        
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

            DispatchQueue.main.async {
                /// Set the window.
                self.windowViewModel.window = self.window
            }
        }
    }
}
#endif
