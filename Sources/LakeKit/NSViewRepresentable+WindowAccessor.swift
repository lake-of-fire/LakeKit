//
//  File.swift
//  
//
//  Created by Alex Ehlke on 7/3/22.
//

import Foundation
import SwiftUI
#if os(macOS)
import AppKit

public struct WindowAccessor: NSViewRepresentable {
    private var binding: Binding<NSWindow?>
    
    public init(for binding: Binding<NSWindow?>) {
        self.binding = binding
    }
    
    public func makeNSView(context: Context) -> NSView {
        let view = NSView()
        Task { @MainActor in
            self.binding.wrappedValue = view.window
        }
        return view
    }
    
    public func updateNSView(_ nsView: NSView, context: Context) {}
}
#endif
