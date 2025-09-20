import SwiftUI

public struct ChevronButtonStyle: ButtonStyle {
    @Environment(\.controlSize) private var controlSize
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.stackSectionListBadgeValue) private var badgeValue
    
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
        case .mini, .small, .regular:
            return 0
        case .large:
            return 4
        case .extraLarge:
            return 6
        default:
            return 0
        }
    }
    
    private var leadingPadding: CGFloat { 0 }
    
    private var trailingPadding: CGFloat { 0 }
    
    private var cornerRadius: CGFloat {
        switch controlSize {
        case .mini: return 10
        case .small: return 12
        case .large: return 16
        case .extraLarge: return 18
        default: return 14
        }
    }
    
    public init() {}
    
    public func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 12) {
            configuration.label
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
                .opacity(isEnabled ? 1 : 0.5)
            if let badgeValue {
                Text("\(badgeValue)")
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(false)
            }
            DisclosureIndicator()
                .opacity(isEnabled ? 1 : 0.4)
        }
        .padding(.leading, leadingPadding)
        .padding(.trailing, trailingPadding)
        .padding(.vertical, verticalPadding)
        .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .leading)
        .background(backgroundColor(isPressed: configuration.isPressed))
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .animation(configuration.isPressed ? .easeInOut(duration: 0.12) : .easeOut(duration: 0.18), value: configuration.isPressed)
    }

    private func backgroundColor(isPressed: Bool) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.primary.opacity(isPressed ? 0.08 : 0.0001))
    }
}

public extension ButtonStyle where Self == ChevronButtonStyle {
    static var chevron: Self { Self() }
}
