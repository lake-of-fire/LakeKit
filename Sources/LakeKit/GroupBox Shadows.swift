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
                RoundedRectangle(cornerRadius: 6)
                    .foregroundColor(.clear)
                    .shadow(
                        color: colorScheme == .dark ? Color.black.opacity(0.8) : Color.black.opacity(0.6),
                        radius: 25,
                        x: 0,
                        y: 0
                    )
            )
    }
}
