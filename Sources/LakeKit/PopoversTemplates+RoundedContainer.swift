// From: https://github.com/aheze/Popovers/blob/05e990e4f46dbcf51bc6b2937b3f9430e8e40164/Sources/Templates/Shapes.swift

#if os(iOS)
import SwiftUI
import Popovers

public extension Templates {
    /**
     A standard container for popovers, complete with arrow.
     */
    struct RoundedContainer<Content: View>: View {
        /// The container's corner radius.
        public var cornerRadius = CGFloat(12)

        /// The container's background/fill color.
        public var backgroundColor = Color(.systemBackground)

        /// The shadow around the content view.
        public var shadow: Shadow? = {
            // See: https://github.com/aheze/Popovers/issues/36#issuecomment-1159931126
            var shadow = Templates.Shadow.system
            shadow.color = Color(.black.withAlphaComponent(0.3))
            return shadow
        }()

        /// The padding around the content view.
        public var padding = CGFloat(16)

        /// The content view.
        @ViewBuilder public var view: Content

        /**
         A standard container for popovers, complete with arrow.
         - parameter arrowSide: Which side to place the arrow on.
         - parameter cornerRadius: The container's corner radius.
         - parameter padding: The padding around the content view.
         - parameter view: The content view.
         */
        public init(
            cornerRadius: CGFloat = CGFloat(12),
            shadow: Shadow? = nil,
            padding: CGFloat = CGFloat(16),
            @ViewBuilder view: () -> Content
        ) {
            self.cornerRadius = cornerRadius
            if let shadow = shadow {
                self.shadow = shadow
            }
            self.padding = padding
            self.view = view()
        }

        public var body: some View {
            PopoverReader { context in
                view
                    .padding(padding)
                    .background(
                        RoundedBackground(
                            cornerRadius: cornerRadius
                        )
                        .background(.ultraThickMaterial)
                        .popoverShadowIfNeeded(shadow: shadow)
                    )
            }
        }
    }
}

public extension Templates {
    // MARK: - Background

    /**
     A shape that has an arrow protruding.
     */
    struct RoundedBackground: Shape {
        /// The shape's corner radius
        public var cornerRadius: CGFloat

        /// The rectangle's width.
        public static var width = CGFloat(48)

        /// The rectangle's height.
        public static var height = CGFloat(12)

        /// Offset the arrow from the sides - otherwise it will overflow out of the corner radius.
        /// This is multiplied by the `cornerRadius`.
        /**

                      /\
                     /_ \
            ----------     <---- Avoid this gap.
                        \
             rectangle  |
         */

        /// Draw the shape.
        public func path(in rect: CGRect) -> Path {
            var path = Path()
            path.addRoundedRect(in: rect, cornerSize: CGSize(width: cornerRadius, height: cornerRadius))
            return path
        }
    }
}
#endif
