import SwiftUI

public protocol DismissButtonStyle: ButtonStyle {}

// Define styles for easier management
public enum DismissButtonStyleType {
    case xMark
    case defaultStyle
}

fileprivate extension View {
    func dismissButtonStyle(_ style: DismissButtonStyleType) -> some View {
        switch style {
        case .xMark:
            return AnyView(self.buttonStyle(XMarkDismissButtonStyle()))
        case .defaultStyle:
            return AnyView(self.buttonStyle(DefaultButtonStyle()))
        }
    }
}

public struct DismissButton: View {
    private let action: (() -> Void)?
    private var style: DismissButtonStyleType
    
    @Environment(\.dismiss) private var dismiss
    
    public var body: some View {
        Button("Done", action: { action?() ?? dismiss() })
            .dismissButtonStyle(style)
//            .accessibilityLabel(Text("Done"))
    }
    
    public init(_ style: DismissButtonStyleType? = nil, action: (() -> Void)? = nil) {
        self.action = action
        // Set the default style based on the platform
#if os(iOS)
        self.style = style ?? .xMark  // Default to XMark style on iOS
#else
        self.style = style ?? .defaultStyle  // Default to DefaultButtonStyle on macOS
#endif
    }
}

public struct XMarkDismissButtonStyle: DismissButtonStyle {
    @Environment(\.colorScheme) var colorScheme
    
    @State private var isHovered = false
    
    public init() {}
    
    private var circleSize: CGFloat {
#if os(iOS)
        return 32
#else
        return 20
#endif
    }
    
    public func makeBody(configuration: Configuration) -> some View {
        ZStack {
            Circle()
                .fill(Color(white: colorScheme == .dark ? 0.19 : 0.93))
                .frame(width: circleSize, height: circleSize)
            Image(systemName: "xmark")
//                .resizable()
//                .scaledToFit()
                .font(.system(size: circleSize * 0.46875, weight: .bold, design: .rounded))
//                .scaleEffect(0.416)
                .foregroundColor(Color(white: colorScheme == .dark ? 0.62 : 0.51))
                .opacity(configuration.isPressed ? 0.7 : 1)
        }
        .padding(2)
        .contentShape(.circle)
        .brightness((isHovered && !configuration.isPressed) ? 0.05 : 0)
        .onHover { isHovered in
            self.isHovered = isHovered
        }
//            .opacity(configuration.isPressed ? 0.18 : 1)
//            .animation(.easeInOut, value: configuration.isPressed)
    }
}
