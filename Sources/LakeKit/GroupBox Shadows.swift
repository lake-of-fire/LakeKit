import SwiftUI


public extension View {
    func groupBoxShadow() -> some View {
        self.modifier(GroupBoxShadowModifier())
    }
}

public struct GroupBoxShadowModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    
    public func body(content: Content) -> some View {
        content
            .background(
                GroupBox {
                    Color.clear
                }
                    .shadow(
                        color: colorScheme == .dark ? Color.black.opacity(0.4) : Color.black.opacity(0.4),
                        radius: 25,
                        x: 0,
                        y: 0
                    )
            )
    }
}
