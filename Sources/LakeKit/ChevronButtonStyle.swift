import SwiftUI

public struct ChevronButtonStyle: ButtonStyle {
    @Environment(\.controlSize) private var controlSize
    @Environment(\.isEnabled) private var isEnabled
    
    @ScaledMetric private var miniMinHeight: CGFloat = 32
    @ScaledMetric private var smallMinHeight: CGFloat = 36
    @ScaledMetric private var regularMinHeight: CGFloat = 44
    @ScaledMetric private var largeMinHeight: CGFloat = 52
    @ScaledMetric private var extraLargeMinHeight: CGFloat = 60
    
    private var minHeight: CGFloat {
        switch controlSize {
        case .mini: return miniMinHeight
        case .small: return smallMinHeight
        case .large: return largeMinHeight
        case .extraLarge: return extraLargeMinHeight
        default: return regularMinHeight
        }
    }
    
    private var verticalPadding: CGFloat {
        switch controlSize {
        case .mini: return 6
        case .small: return 7
        case .large: return 10
        case .extraLarge: return 12
        default: return 8
        }
    }
    
    private var horizontalPadding: CGFloat {
        switch controlSize {
        case .mini: return 12
        case .small: return 14
        case .large: return 20
        case .extraLarge: return 22
        default: return 16
        }
    }
    
    public init() {}
    
    public func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 12) {
            configuration.label
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
                .foregroundStyle(isEnabled ? .primary : .secondary)
            DisclosureIndicator()
                .opacity(isEnabled ? 1 : 0.4)
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .leading)
        .background(backgroundColor(isPressed: configuration.isPressed))
        .contentShape(Rectangle())
        .animation(configuration.isPressed ? .easeInOut(duration: 0.12) : .easeOut(duration: 0.18), value: configuration.isPressed)
    }

    private func backgroundColor(isPressed: Bool) -> some View {
        Rectangle()
            .fill(Color.primary.opacity(isPressed ? 0.08 : 0.0001))
    }
}

public extension ButtonStyle where Self == ChevronButtonStyle {
    static var chevron: Self { Self() }
}
