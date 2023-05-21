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
                    .foregroundColor(.init(white: 0.0000001, opacity: 0.0000001))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .shadow(
                        color: colorScheme == .dark ? Color.black.opacity(0.7) : Color.black.opacity(0.65),
                        radius: 30,
                        x: 0,
                        y: 0)
            )
    }
    
    public init(cornerRadius: CGFloat = 6) {
        self.cornerRadius = cornerRadius
    }
}
