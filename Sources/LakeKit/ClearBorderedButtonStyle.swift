import SwiftUI

public struct ClearBorderedButtonStyle: ButtonStyle {
    @Environment(\.controlSize) private var controlSize
    
#if os(iOS)
    private var miniMinWidth: CGFloat {
        smallMinWidth
    }
    private var miniMinHeight: CGFloat {
        smallMinHeight
    }
#elseif os(macOS)
    @ScaledMetric private var miniMinWidth: CGFloat = 28
    @ScaledMetric private var miniMinHeight: CGFloat = 28
#endif
    
    @ScaledMetric private var smallMinWidth: CGFloat = 30
    @ScaledMetric private var smallMinHeight: CGFloat = 30
    
    @ScaledMetric private var regularMinWidth: CGFloat = 44
    @ScaledMetric private var regularMinHeight: CGFloat = 44
    
    @ScaledMetric private var largeMinWidth: CGFloat = 52
    @ScaledMetric private var largeMinHeight: CGFloat = 52
    
    @ScaledMetric private var extraLargeMinWidth: CGFloat = 60
    @ScaledMetric private var extraLargeMinHeight: CGFloat = 60
    
#if os(macOS)
    private let sizeFactor: CGFloat = 0.666
#else
    private let sizeFactor: CGFloat = 1
#endif
    private var minWidth: CGFloat {
        let width = {
            switch controlSize {
            case .mini: return miniMinWidth
            case .small: return smallMinWidth
            case .regular: return regularMinWidth
            case .large: return largeMinWidth
            case .extraLarge: return extraLargeMinWidth
            default: return regularMinWidth
            }
        }()
        return width * sizeFactor
    }
    
    private var minHeight: CGFloat {
        let height = {
            switch controlSize {
            case .mini: return miniMinHeight
            case .small: return smallMinHeight
            case .regular: return regularMinHeight
            case .large: return largeMinHeight
            case .extraLarge: return extraLargeMinHeight
            default: return regularMinHeight
            }
        }()
        return height * sizeFactor
    }
    
    public func makeBody(configuration: Configuration) -> some View {
        ClearBorderedButtonBody(
            configuration: configuration,
            minWidth: minWidth,
            minHeight: minHeight
        )
    }
}

private struct ClearBorderedButtonBody: View {
    let configuration: ClearBorderedButtonStyle.Configuration
    let minWidth: CGFloat
    let minHeight: CGFloat

    @State private var labelSize: CGSize = .zero

    var body: some View {
        ZStack {
            configuration.label
                .tint(nil)
                .opacity(configuration.isPressed ? 0.4 : 1)
                .background(
                    GeometryReader { proxy in
                        Color.clear
                            .preference(key: ClearBorderedButtonLabelSizeKey.self, value: proxy.size)
                    }
                )
#if os(iOS)
                .animation(configuration.isPressed ? nil : .easeOut(duration: 0.18), value: configuration.isPressed)
#endif
        }
        .background(.white.opacity(0.0000000001))
        .frame(minWidth: minWidth, minHeight: minHeight)
        .fixedSize()
        .background(
            GeometryReader { proxy in
                let trailingPadding = resolvedTrailingPadding(totalWidth: proxy.size.width)
                let resolvedHeight = resolvedLabelHeight(totalHeight: proxy.size.height)
                Color.clear
                    .preference(key: ClearBorderedButtonHeightKey.self, value: resolvedHeight)
                    .preference(key: ClearBorderedButtonTrailingPaddingKey.self, value: trailingPadding)
            }
        )
        .onPreferenceChange(ClearBorderedButtonLabelSizeKey.self) { newSize in
            labelSize = newSize
        }
    }

    private func resolvedTrailingPadding(totalWidth: CGFloat) -> CGFloat {
        let width = max(totalWidth, minWidth)
        let effectiveLabelWidth = labelSize.width > 0 ? labelSize.width : width
        return max(0, (width - effectiveLabelWidth) / 2)
    }

    private func resolvedLabelHeight(totalHeight: CGFloat) -> CGFloat {
        guard labelSize.height > 0 else { return totalHeight }
        return labelSize.height
    }
}

public extension ButtonStyle where Self == ClearBorderedButtonStyle {
    static var clearBordered: Self { Self() }
}

private struct ClearBorderedButtonLabelSizeKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

public struct ClearBorderedButtonHeightKey: PreferenceKey {
    public static var defaultValue: CGFloat = 0
    public static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        let next = nextValue()
        guard next > 0 else { return }
        if value == 0 {
            value = next
        } else {
            value = min(value, next)
        }
    }
}

public struct ClearBorderedButtonTrailingPaddingKey: PreferenceKey {
    public static var defaultValue: CGFloat = 0
    public static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
