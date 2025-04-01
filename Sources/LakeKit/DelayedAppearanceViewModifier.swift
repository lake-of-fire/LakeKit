import SwiftUI

public struct DelayedAppearanceViewModifier: ViewModifier {
    var delay: Double
    var forceDisplay: Bool
    
    @State private var isVisible: Bool = false
    
    public init(delay: Double, forceDisplay: Bool = false) {
        self.delay = delay
        self.forceDisplay = forceDisplay
    }
    
    public func body(content: Content) -> some View {
        content
            .opacity(isVisible || forceDisplay ? 1 : 0)
            .onAppear {
                if forceDisplay {
                    isVisible = true
                } else {
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        withAnimation {
                            isVisible = true
                        }
                    }
                }
            }
    }
}

public extension View {
    func delayedAppearance(delay: Double = 0.4, forceDisplay: Bool = false) -> some View {
        self.modifier(DelayedAppearanceViewModifier(delay: delay, forceDisplay: forceDisplay))
    }
}
