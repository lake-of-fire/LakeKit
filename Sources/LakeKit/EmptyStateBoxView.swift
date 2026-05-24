import SwiftUI

private struct EmptyStateBoxFillsAvailableHeightKey: EnvironmentKey {
    static let defaultValue = false
}

public extension EnvironmentValues {
    var emptyStateBoxFillsAvailableHeight: Bool {
        get { self[EmptyStateBoxFillsAvailableHeightKey.self] }
        set { self[EmptyStateBoxFillsAvailableHeightKey.self] = newValue }
    }
}

/// A reusable empty-state view that matches the platform look & feel.
/// - Uses a GroupBox with the system image as the label.
/// - Places title + supporting text on the leading side.
/// - Accepts an optional trailing control (e.g., a “Create” button).
public struct EmptyStateBoxView<Trailing: View>: View {
    public let title: Text
    public let text: Text
    public let systemImageName: String
    @ViewBuilder public var trailingView: Trailing
    public let groupBoxAppearance: StackListGroupBoxStyleOption
    public let minimumContentHeight: CGFloat?

    @Environment(\.controlSize) private var controlSize
    @Environment(\.stackListStyle) private var stackListStyle
    @Environment(\.stackListIsGroupedContext) private var stackListGroupedContext
    @Environment(\.emptyStateBoxFillsAvailableHeight) private var fillsAvailableHeight
    @ScaledMetric(relativeTo: .body) private var groupedMinHeight: CGFloat = 90

    private var hasTrailingContent: Bool {
        !(Trailing.self == EmptyView.self)
    }

    private var shouldShowTrailingSpacer: Bool {
        hasTrailingContent && controlSize != .small && controlSize != .mini
    }
    
    public init(
        title: Text,
        text: Text,
        systemImageName: String,
        groupBoxAppearance: StackListGroupBoxStyleOption = .automatic,
        minimumContentHeight: CGFloat? = nil,
        @ViewBuilder trailingView: () -> Trailing
    ) {
        self.title = title
        self.text = text
        self.systemImageName = systemImageName
        self.groupBoxAppearance = groupBoxAppearance
        self.minimumContentHeight = minimumContentHeight
        self.trailingView = trailingView()
    }

    public init(
        title: Text,
        text: Text,
        systemImageName: String,
        groupBoxAppearance: StackListGroupBoxStyleOption = .automatic,
        minimumContentHeight: CGFloat? = nil,
        fixedHeight: CGFloat?,
        @ViewBuilder trailingView: () -> Trailing
    ) {
        self.init(
            title: title,
            text: text,
            systemImageName: systemImageName,
            groupBoxAppearance: groupBoxAppearance,
            minimumContentHeight: minimumContentHeight,
            trailingView: trailingView
        )
    }
    
    public var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 6) {
                headerLabel
                if !usesCompactControlSize {
                    text
                        .font(.footnote)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .environment(\._lineHeightMultiple, 0.9)
            .imageScale(.small)
            .foregroundStyle(.secondary)
            .padding(contentPadding)
            .frame(
                maxWidth: .infinity,
                minHeight: preferredMinHeight,
                maxHeight: fillsAvailableHeight ? .infinity : nil,
                alignment: .bottomLeading
            )
            .modifier {
                if #available(iOS 16, macOS 13, *) {
                    $0.backgroundStyle(.secondary)
                } else { $0 }
            }
        } label: {
            if usesInlineHeader {
                EmptyView()
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Image(systemName: systemImageName)
                        .imageScale(.large)
                        .foregroundStyle(.tertiary)
                    if hasTrailingContent {
                        if shouldShowTrailingSpacer {
                            Spacer(minLength: 8)
                        }
                        trailingView
                            .labelStyle(.titleAndIcon)
                            .modifier(EmptyStateActionButtonModifier())
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .environment(\.stackListBackgroundColorOverride, preferredBackgroundColor)
        .applyStackListGroupBoxStyle(groupBoxAppearance, defaultIsGrouped: isGroupedAppearance)
        .frame(
            maxWidth: .infinity,
            minHeight: minimumContentHeight,
            maxHeight: fillsAvailableHeight ? .infinity : nil,
            alignment: .leading
        )
        .listRowInsets(.init())
        .modifier {
            if !fillsAvailableHeight && !usesCompactControlSize {
                $0.fixedSize(horizontal: false, vertical: true)
            } else {
                $0
            }
        }
        //.enableInjection()
    }
}

private struct EmptyStateActionButtonModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .controlSize(.small)
            .font(.footnote)
            .foregroundStyle(Color.accentColor)
            .modifier {
                if #available(iOS 16, macOS 13, *) {
                    $0
                        .fontWeight(.semibold)
                        .backgroundStyle(.secondary)
                } else { $0 }
            }
#if os(macOS)
            .buttonStyle(.bordered)
#endif
    }
}

// Convenience initializer when no trailing view is supplied.
public extension EmptyStateBoxView where Trailing == EmptyView {
    init(
        title: Text,
        text: Text,
        systemImageName: String,
        groupBoxAppearance: StackListGroupBoxStyleOption = .automatic,
        minimumContentHeight: CGFloat? = nil
    ) {
        self.init(
            title: title,
            text: text,
            systemImageName: systemImageName,
            groupBoxAppearance: groupBoxAppearance,
            minimumContentHeight: minimumContentHeight
        ) { EmptyView() }
    }

    init(
        title: Text,
        text: Text,
        systemImageName: String,
        groupBoxAppearance: StackListGroupBoxStyleOption = .automatic,
        minimumContentHeight: CGFloat? = nil,
        fixedHeight: CGFloat?
    ) {
        self.init(
            title: title,
            text: text,
            systemImageName: systemImageName,
            groupBoxAppearance: groupBoxAppearance,
            minimumContentHeight: minimumContentHeight
        )
    }
}

private extension EmptyStateBoxView {
    var isGroupedAppearance: Bool {
        stackListGroupedContext || stackListStyle == .grouped
    }

    var preferredBackgroundColor: Color {
        switch groupBoxAppearance {
        case .clear:
            return .clear
        case .grouped:
            return Color.stackListCardBackgroundGrouped
        case .plain:
            return Color.stackListCardBackgroundPlain
        case .automatic:
            return isGroupedAppearance ? Color.stackListCardBackgroundGrouped : Color.stackListCardBackgroundPlain
        }
    }

    var preferredMinHeight: CGFloat? {
        if usesCompactControlSize { return minimumContentHeight }
        let defaultMinHeight: CGFloat?
        switch groupBoxAppearance {
        case .clear:
            defaultMinHeight = nil
        case .grouped:
            defaultMinHeight = groupedMinHeight
        case .plain:
            defaultMinHeight = nil
        case .automatic:
            defaultMinHeight = isGroupedAppearance ? groupedMinHeight : nil
        }
        guard let minimumContentHeight else { return defaultMinHeight }
        guard let defaultMinHeight else { return minimumContentHeight }
        return max(defaultMinHeight, minimumContentHeight)
    }

    var usesInlineHeader: Bool {
        usesCompactControlSize
    }

    var usesCompactControlSize: Bool {
        controlSize == .small || controlSize == .mini
    }

    @ViewBuilder
    var headerLabel: some View {
        if usesInlineHeader {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: systemImageName)
                    .imageScale(.medium)
                    .foregroundStyle(.tertiary)
                title
                    .font(.subheadline)
                    .bold()
                    .fixedSize(horizontal: false, vertical: true)
            }
        } else {
            title
                .font(.subheadline)
                .bold()
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    var contentPadding: EdgeInsets {
        switch groupBoxAppearance {
        case .clear:
            return EdgeInsets()
        default:
            return EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0)
        }
    }

}
