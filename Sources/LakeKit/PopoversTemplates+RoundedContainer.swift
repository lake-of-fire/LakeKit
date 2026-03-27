#if os(iOS)
import SwiftUI

public enum Templates {}

public extension Templates {
    struct Shadow {
        public var color: Color
        public var radius: CGFloat
        public var x: CGFloat
        public var y: CGFloat

        public init(
            color: Color = Color.black.opacity(0.3),
            radius: CGFloat = 16,
            x: CGFloat = 0,
            y: CGFloat = 8
        ) {
            self.color = color
            self.radius = radius
            self.x = x
            self.y = y
        }

        public static var system: Shadow {
            Shadow()
        }
    }

    struct RoundedContainer<Content: View>: View {
        public var cornerRadius = CGFloat(24)
        public var backgroundColor = Color(uiColor: .systemBackground)
        public var shadow: Shadow? = {
            var shadow = Templates.Shadow.system
            shadow.color = Color.black.opacity(0.3)
            return shadow
        }()
        public var padding = CGFloat(16)

        @ViewBuilder public var view: Content

        public init(
            cornerRadius: CGFloat = 12,
            shadow: Shadow? = nil,
            padding: CGFloat = 16,
            @ViewBuilder view: () -> Content
        ) {
            self.cornerRadius = cornerRadius
            self.shadow = shadow
            self.padding = padding
            self.view = view()
        }

        public var body: some View {
            view
                .padding(padding)
                .background(backgroundColor)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(Color.primary.opacity(0.15), lineWidth: 1.5)
                )
                .popoverShadowIfNeeded(shadow: shadow)
        }
    }

    struct RoundedBackground: Shape {
        public var cornerRadius: CGFloat
        public static var width = CGFloat(48)
        public static var height = CGFloat(12)

        public func path(in rect: CGRect) -> Path {
            var path = Path()
            path.addRoundedRect(
                in: rect,
                cornerSize: CGSize(width: cornerRadius, height: cornerRadius)
            )
            return path
        }
    }
}

private extension View {
    @ViewBuilder
    func popoverShadowIfNeeded(shadow: Templates.Shadow?) -> some View {
        if let shadow {
            self.shadow(
                color: shadow.color,
                radius: shadow.radius,
                x: shadow.x,
                y: shadow.y
            )
        } else {
            self
        }
    }
}
#endif
