#if os(macOS)
import SwiftUI

public extension Scene {
    func windowGroupDefaultSize(width: CGFloat, height: CGFloat) -> some Scene {
        if #available(macOS 13.0, *) {
            return defaultSize(width: width, height: height)
        } else {
            return self
        }
    }
}
#endif
