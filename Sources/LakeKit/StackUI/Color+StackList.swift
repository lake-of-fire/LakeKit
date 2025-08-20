import SwiftUI
#if os(iOS)
import UIKit
#endif

public extension Color {
    static var stackListGroupedBackground: Color {
#if os(iOS)
        return Color.systemGray4.opacity(0.4)
#else
        return Color.systemGroupedBackground
#endif
    }
}
