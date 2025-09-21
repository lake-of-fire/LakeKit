import SwiftUI

public protocol DismissButtonStyle: ButtonStyle {}

// Define styles for easier management
public enum DismissButtonStyleType {
    case xMark
    case chevron
    case defaultStyle
}

fileprivate extension View {
    func dismissButtonStyle(
        _ style: DismissButtonStyleType,
        fill: Bool,
        colorScheme: ColorScheme,
        controlSize: ControlSize
    ) -> some View {
        switch style {
        case .xMark:
            return AnyView(
                self.buttonStyle(
                    XMarkDismissButtonStyle(
                        fill: fill,
                        colorScheme: colorScheme,
                        controlSize: controlSize
                    )
                )
            )
        case .chevron:
            return AnyView(
                self.buttonStyle(
                    ChevronDismissButtonStyle(
                        fill: fill,
                        colorScheme: colorScheme,
                        controlSize: controlSize
                    )
                )
            )
        case .defaultStyle:
            return AnyView(self.buttonStyle(DefaultButtonStyle()))
        }
    }
}

public struct DismissButton: View {
    private let action: (() -> Void)?
    private var style: DismissButtonStyleType
    private var fill: Bool
    private let label: AnyView?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.controlSize) private var controlSize
    @Environment(\.colorScheme) private var colorScheme

    public var body: some View {
        Button(action: { action?() ?? dismiss() }) {
            if let label {
                label
            } else {
                Text("Done")
            }
        }
            .dismissButtonStyle(
                style,
                fill: fill,
                colorScheme: colorScheme,
                controlSize: controlSize
            )
        //            .accessibilityLabel(Text("Done"))
    }

    public init(_ style: DismissButtonStyleType? = nil, fill: Bool = false, action: (() -> Void)? = nil) {
        self.action = action
        self.fill = fill
        self.label = nil
        // Set the default style based on the platform
#if os(iOS)
        self.style = style ?? .xMark  // Default to XMark style on iOS
#else
        self.style = style ?? .defaultStyle  // Default to DefaultButtonStyle on macOS
#endif
    }

    public init<Label: View>(
        style: DismissButtonStyleType? = nil,
        fill: Bool = false,
        action: (() -> Void)? = nil,
        @ViewBuilder label: () -> Label
    ) {
        self.action = action
        self.fill = fill
        self.label = AnyView(label())
#if os(iOS)
        self.style = style ?? .xMark
#else
        self.style = style ?? .defaultStyle
#endif
    }
}

public struct BaseDismissButtonStyle: DismissButtonStyle {
    private let systemImageName: String
    private let fill: Bool
    private let colorScheme: ColorScheme
    private let controlSize: ControlSize
    
    @State private var isHovered = false
    
    public init(
        systemImageName: String,
        fill: Bool,
        colorScheme: ColorScheme,
        controlSize: ControlSize
    ) {
        self.systemImageName = systemImageName
        self.fill = fill
        self.colorScheme = colorScheme
        self.controlSize = controlSize
    }
    
    private var fontSize: CGFloat {
#if os(iOS)
//        return circleSize * 0.44
        return circleSize * 0.4
//        return circleSize * 0.34
#else
        return circleSize * 0.46875
//        return circleSize * 0.4
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
            return size * 1 //0.85
        case .mini:
            return size * 1 //0.85
        @unknown default:
            return size
        }
    }
    
    public func makeBody(configuration: Configuration) -> some View {
        if #available(iOS 26, macOS 26, *) {
            Image(systemName: systemImageName + (fill ? ".circle.fill" : ""))
        } else {
            ZStack {
                Circle()
                    .fill([.mini, .small].contains(controlSize) ? Color(white: 1, opacity: 0.0000000001) : Color(white: colorScheme == .dark ? 0.19 : 0.93))
                    .frame(width: circleSize, height: circleSize)
                Image(systemName: systemImageName)
                    .font(.system(size: fontSize, weight: .bold, design: .rounded))
                    .foregroundColor(Color(white: colorScheme == .dark ? 0.62 : 0.51))
                    .opacity(configuration.isPressed ? 0.7 : 1)
            }
            .padding(2)
            .contentShape(.circle)
            .brightness((isHovered && !configuration.isPressed) ? 0.05 : 0)
            .onHover { isHovered in
                self.isHovered = isHovered
            }
        }
    }
}

public struct XMarkDismissButtonStyle: DismissButtonStyle {
    private let fill: Bool
    private let colorScheme: ColorScheme
    private let controlSize: ControlSize
    
    public init(
        fill: Bool,
        colorScheme: ColorScheme,
        controlSize: ControlSize
    ) {
        self.fill = fill
        self.colorScheme = colorScheme
        self.controlSize = controlSize
    }
    
    public func makeBody(configuration: Configuration) -> some View {
        BaseDismissButtonStyle(
            systemImageName: "xmark",
            fill: fill,
            colorScheme: colorScheme,
            controlSize: controlSize
        ).makeBody(configuration: configuration)
    }
}

public struct ChevronDismissButtonStyle: DismissButtonStyle {
    private let fill: Bool
    private let colorScheme: ColorScheme
    private let controlSize: ControlSize
    
    public init(
        fill: Bool,
        colorScheme: ColorScheme,
        controlSize: ControlSize
    ) {
        self.fill = fill
        self.colorScheme = colorScheme
        self.controlSize = controlSize
    }
    
    public func makeBody(configuration: Configuration) -> some View {
        BaseDismissButtonStyle(
            systemImageName: "chevron.down",
            fill: fill,
            colorScheme: colorScheme,
            controlSize: controlSize
        ).makeBody(configuration: configuration)
    }
}
