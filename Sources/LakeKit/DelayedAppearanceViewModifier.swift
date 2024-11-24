import SwiftUI

public struct DelayedAppearanceViewModifier: ViewModifier {
    var delay: Double
    
    @State private var isVisible: Bool = false
    
    public init(delay: Double) {
        self.delay = delay
    }
    
    public func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    withAnimation {
                        isVisible = true
                    }
                }
            }
    }
}


public extension View {
    func delayedAppearance(delay: Double = 0.4) -> some View {
        self.modifier(DelayedAppearanceViewModifier(delay: delay))
    }
}
