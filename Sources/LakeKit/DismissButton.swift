import SwiftUI

public protocol DismissButtonStyle: ButtonStyle {}

// Define styles for easier management
public enum DismissButtonStyleType {
    case xMark
    case chevron
    case defaultStyle
}

fileprivate extension View {
    func dismissButtonStyle(_ style: DismissButtonStyleType) -> some View {
        switch style {
        case .xMark:
            return AnyView(self.buttonStyle(XMarkDismissButtonStyle()))
        case .chevron:
            return AnyView(self.buttonStyle(ChevronDismissButtonStyle()))
        case .defaultStyle:
            return AnyView(self.buttonStyle(DefaultButtonStyle()))
        }
    }
}

public struct DismissButton: View {
    private let action: (() -> Void)?
    private var style: DismissButtonStyleType
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.controlSize) private var controlSize
    
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
    @Environment(\.controlSize) var controlSize
    
    @State private var isHovered = false
    
    public init() {}
    
    private var fontSize: CGFloat {
#if os(iOS)
        return circleSize * 0.44
#else
        return circleSize * 0.46875
#endif
    }
    
    private var circleSize: CGFloat {
        var size: CGFloat
#if os(iOS)
        size = 32
#else
        size = 20
#endif
        switch controlSize {
        case .extraLarge:
            return size * 1.75
        case .large:
            return size * 1.5
        case .regular:
            return size
        case .small:
            return size * 0.85
        case .mini:
            return size * 0.85
        @unknown default:
            return size
        }
    }
    
    public func makeBody(configuration: Configuration) -> some View {
        ZStack {
            Circle()
                .fill([.mini, .small].contains(controlSize) ? Color(white: 1, opacity: 0.0000000001) : Color(white: colorScheme == .dark ? 0.19 : 0.93))
                .frame(width: circleSize, height: circleSize)
            Image(systemName: "xmark")
            //                .resizable()
            //                .scaledToFit()
                .font(.system(size: fontSize, weight: .bold, design: .rounded))
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

public struct ChevronDismissButtonStyle: DismissButtonStyle {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.controlSize) var controlSize
    
    @State private var isHovered = false
    
    public init() {}
    
    private var fontSize: CGFloat {
#if os(iOS)
        return circleSize * 0.44
#else
        return circleSize * 0.46875
#endif
    }
    
    private var circleSize: CGFloat {
        var size: CGFloat
#if os(iOS)
        size = 32
#else
        size = 20
#endif
        switch controlSize {
        case .extraLarge:
            return size * 1.75
        case .large:
            return size * 1.5
        case .regular:
            return size
        case .small:
            return size * 0.85
        case .mini:
            return size * 0.85
        @unknown default:
            return size
        }
    }
    
    public func makeBody(configuration: Configuration) -> some View {
        ZStack {
            Circle()
                .fill([.mini, .small].contains(controlSize) ? Color(white: 1, opacity: 0.0000000001) : Color(white: colorScheme == .dark ? 0.19 : 0.93))
                .frame(width: circleSize, height: circleSize)
            Image(systemName: "chevron.down")
            //                .resizable()
            //                .scaledToFit()
                .font(.system(size: fontSize, weight: .bold, design: .rounded))
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
