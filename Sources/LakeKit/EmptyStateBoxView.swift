import SwiftUI

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

    @Environment(\.controlSize) private var controlSize
    @Environment(\.stackListStyle) private var stackListStyle
    @Environment(\.stackListIsGroupedContext) private var stackListGroupedContext
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
        @ViewBuilder trailingView: () -> Trailing
    ) {
        self.title = title
        self.text = text
        self.systemImageName = systemImageName
        self.groupBoxAppearance = groupBoxAppearance
        self.trailingView = trailingView()
    }
    
    public var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 6) {
                headerLabel
                text
                    .font(.footnote)
            }
            .environment(\._lineHeightMultiple, 0.9)
            .imageScale(.small)
            .foregroundStyle(.secondary)
            .padding(contentPadding)
            .frame(maxWidth: .infinity, minHeight: preferredMinHeight, alignment: .bottomLeading)
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
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            .font(.footnote)
                            .modifier {
                                if #available(iOS 16, macOS 13, *) {
                                    $0.fontWeight(.semibold)
                                } else { $0 }
                            }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .environment(\.stackListBackgroundColorOverride, preferredBackgroundColor)
        .applyStackListGroupBoxStyle(groupBoxAppearance, defaultIsGrouped: isGroupedAppearance)
        .frame(maxWidth: .infinity, alignment: .leading)
        .listRowInsets(.init())
        .fixedSize(horizontal: false, vertical: true)
        //.enableInjection()
    }
}

// Convenience initializer when no trailing view is supplied.
public extension EmptyStateBoxView where Trailing == EmptyView {
    init(title: Text, text: Text, systemImageName: String, groupBoxAppearance: StackListGroupBoxStyleOption = .automatic) {
        self.init(title: title, text: text, systemImageName: systemImageName, groupBoxAppearance: groupBoxAppearance) { EmptyView() }
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
        if controlSize == .small || controlSize == .mini { return nil }
        switch groupBoxAppearance {
        case .clear:
            return nil
        case .grouped:
            return groupedMinHeight
        case .plain:
            return nil
        case .automatic:
            return isGroupedAppearance ? groupedMinHeight : nil
        }
    }

    var usesInlineHeader: Bool {
        controlSize == .small || controlSize == .mini
    }

    @ViewBuilder
    var headerLabel: some View {
        if usesInlineHeader {
            Label {
                title
                    .font(.subheadline)
                    .bold()
            } icon: {
                Image(systemName: systemImageName)
                    .imageScale(.medium)
                    .foregroundStyle(.tertiary)
            }
        } else {
            title
                .font(.subheadline)
                .bold()
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
