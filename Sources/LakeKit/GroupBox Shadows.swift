import SwiftUI


public extension View {
    func groupBoxShadow(cornerRadius: CGFloat = 6) -> some View {
        self.modifier(GroupBoxShadowModifier(cornerRadius: cornerRadius))
    }
}

public struct GroupBoxShadowModifier: ViewModifier {
    let cornerRadius: CGFloat
    @Environment(\.colorScheme) private var colorScheme
    
    public func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .foregroundColor(.clear)
                    .shadow(
                        color: colorScheme == .dark ? Color.black.opacity(0.8) : Color.black.opacity(0.6),
                        radius: 25,
                        x: 0,
                        y: 0
                    )
            )
    }
    
    public init(cornerRadius: CGFloat = 6) {
        self.cornerRadius = cornerRadius
    }
}
