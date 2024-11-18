import SwiftUI

public struct DelayedAppearanceViewModifier: ViewModifier {
    var delay: Double
    
    public init(delay: Double) {
        self.delay = delay
    }
    
    public func body(content: Content) -> some View {
        content
//            .opacity(0)
//            .animation(.default, value: UUID()) // Animate on any change
            .transition(.asymmetric(insertion: .opacity.animation(.default.delay(delay)), removal: .opacity))
    }
}

public extension View {
    func delayedAppearance(delay: Double = 0.4) -> some View {
        self.modifier(DelayedAppearanceViewModifier(delay: delay))
    }
}
