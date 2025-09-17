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
    @ScaledMetric private var miniMinWidth: CGFloat = 30
    @ScaledMetric private var miniMinHeight: CGFloat = 30
#endif
    
    @ScaledMetric private var smallMinWidth: CGFloat = 32
    @ScaledMetric private var smallMinHeight: CGFloat = 32
    
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
        ZStack {
            configuration.label
//                .foregroundColor(.accentColor)
                .tint(nil)
                .opacity(configuration.isPressed ? 0.4 : 1)
#if os(iOS)
                .animation(configuration.isPressed ? nil : .easeOut(duration: 0.18), value: configuration.isPressed)
#endif
        }
        .background(.white.opacity(0.0000000001))
//        .frame(minWidth: minWidth, minHeight: minHeight)
        .frame(minWidth: minWidth, minHeight: minHeight)
        .fixedSize()
        .background(
            GeometryReader { proxy in
                Color.clear.preference(key: ClearBorderedButtonHeightKey.self, value: proxy.size.height)
            }
        )
//                .contentShape(Rectangle())
//        .contentShape(RoundedRectangle(cornerRadius: minHeight / 7))
//        .clipShape(RoundedRectangle(cornerRadius: minHeight / 7))
    }
}

public extension ButtonStyle where Self == ClearBorderedButtonStyle {
    static var clearBordered: Self { Self() }
}

public struct ClearBorderedButtonHeightKey: PreferenceKey {
    public static var defaultValue: CGFloat = 0
    public static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
