import SwiftUI
#if os(macOS)
import AppKit
#endif
#if os(iOS)
import UIKit
#endif

public extension Color {
    static var stackListGroupedBackground: Color {
#if os(iOS)
        return Color.systemGray4.opacity(0.4)
#else
        return Color.systemGray4.opacity(0.4)
//        return Color.systemGroupedBackground
#endif
    }

    static var stackListCardBackgroundPlain: Color {
#if os(iOS)
        return Color.secondarySystemBackground
#elseif os(macOS)
        return Color(NSColor.windowBackgroundColor)
#else
        return Color.white
#endif
    }

    static var stackListCardBackgroundGrouped: Color {
#if os(iOS)
        return Color.secondarySystemGroupedBackground
#elseif os(macOS)
        return Color(NSColor.controlBackgroundColor)
#else
        return Color.secondary
#endif
    }
}
