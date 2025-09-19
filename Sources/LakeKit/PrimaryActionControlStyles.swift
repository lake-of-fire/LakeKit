import SwiftUI

public struct PrimaryActionButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        PrimaryActionButton(configuration: configuration)
    }

    private struct PrimaryActionButton: View {
        @Environment(\.primaryActionButtonMaxHeight) private var maxHeight
        let configuration: Configuration

        private var cornerRadius: CGFloat { 16 }
        private var baseBackgroundOpacity: Double { 0.12 }
        private var pressedBackgroundOpacity: Double { 0.18 }
        private var borderOpacity: Double { 0.25 }

        var body: some View {
            configuration.label
                .labelStyle(PrimaryActionButtonLabelStyle())
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity, alignment: .top)
                .frame(minHeight: maxHeight > 0 ? maxHeight : nil, alignment: .top)
                .background(backgroundShape.fill(backgroundColor))
                .overlay(backgroundShape.strokeBorder(borderColor, lineWidth: 1))
                .foregroundStyle(foregroundColor)
                .contentShape(backgroundShape)
                .background(
                    GeometryReader { proxy in
                        Color.clear
                            .preference(
                                key: PrimaryActionButtonHeightPreferenceKey.self,
                                value: proxy.size.height
                            )
                    }
                )
        }

        private var backgroundShape: some InsettableShape {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        }

        private var backgroundColor: Color {
            let opacity = configuration.isPressed ? pressedBackgroundOpacity : baseBackgroundOpacity
            return Color.accentColor.opacity(opacity)
        }

        private var borderColor: Color {
            Color.accentColor.opacity(borderOpacity)
        }

        private var foregroundColor: Color {
            Color.accentColor
        }
    }
}

public extension ButtonStyle where Self == PrimaryActionButtonStyle {
    static var primaryAction: PrimaryActionButtonStyle { PrimaryActionButtonStyle() }
}

public struct PrimaryActionButtonLabelStyle: LabelStyle {
    public init(verticalSpacing: CGFloat = 8) {
        self.verticalSpacing = verticalSpacing
    }

    private let verticalSpacing: CGFloat

    public func makeBody(configuration: Configuration) -> some View {
        VStack(spacing: verticalSpacing) {
            configuration.icon
                .font(.title3)

            configuration.title
                .font(.headline)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }
}

public extension LabelStyle where Self == PrimaryActionButtonLabelStyle {
    static var primaryActionButton: PrimaryActionButtonLabelStyle { PrimaryActionButtonLabelStyle() }
}

public struct PrimaryActionControlGroupStyle: ControlGroupStyle {
    public init(spacing: CGFloat = 12) {
        self.spacing = spacing
    }

    private let spacing: CGFloat

    public func makeBody(configuration: Configuration) -> some View {
        PrimaryActionControlGroup(spacing: spacing, configuration: configuration)
    }

    private struct PrimaryActionControlGroup: View {
        let spacing: CGFloat
        let configuration: Configuration

        @State private var maxHeight: CGFloat = 0

        var body: some View {
            HStack(alignment: .top, spacing: spacing) {
                configuration.content
            }
            .frame(maxWidth: .infinity, alignment: .top)
            .environment(\.primaryActionButtonMaxHeight, maxHeight)
            .onPreferenceChange(PrimaryActionButtonHeightPreferenceKey.self) { newValue in
                guard newValue > 0 else { return }
                maxHeight = newValue
            }
        }
    }
}

public extension ControlGroupStyle where Self == PrimaryActionControlGroupStyle {
    static func primaryAction(spacing: CGFloat = 12) -> PrimaryActionControlGroupStyle {
        PrimaryActionControlGroupStyle(spacing: spacing)
    }
}

private struct PrimaryActionButtonHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct PrimaryActionButtonMaxHeightKey: EnvironmentKey {
    static var defaultValue: CGFloat = 0
}

private extension EnvironmentValues {
    var primaryActionButtonMaxHeight: CGFloat {
        get { self[PrimaryActionButtonMaxHeightKey.self] }
        set { self[PrimaryActionButtonMaxHeightKey.self] = newValue }
    }
}
