import SwiftUI

public let stackListCornerRadius: CGFloat = 20

private struct StackListBackgroundColorOverrideKey: EnvironmentKey {
    static let defaultValue: Color? = nil
}

private struct StackListIsGroupedContextKey: EnvironmentKey {
    static let defaultValue = false
}

private struct StackListGroupBoxContentSpacingKey: EnvironmentKey {
    static let defaultValue: CGFloat = 12
}

private struct StackListGroupBoxContentInsetsKey: EnvironmentKey {
    static let defaultValue = EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)
}

public extension EnvironmentValues {
    public var stackListBackgroundColorOverride: Color? {
        get { self[StackListBackgroundColorOverrideKey.self] }
        set { self[StackListBackgroundColorOverrideKey.self] = newValue }
    }

    public var stackListIsGroupedContext: Bool {
        get { self[StackListIsGroupedContextKey.self] }
        set { self[StackListIsGroupedContextKey.self] = newValue }
    }

    public var stackListGroupBoxContentSpacing: CGFloat {
        get { self[StackListGroupBoxContentSpacingKey.self] }
        set { self[StackListGroupBoxContentSpacingKey.self] = newValue }
    }

    public var stackListGroupBoxContentInsets: EdgeInsets {
        get { self[StackListGroupBoxContentInsetsKey.self] }
        set { self[StackListGroupBoxContentInsetsKey.self] = newValue }
    }
}

public enum StackListGroupBoxDefaults {
    public static var contentInsets: EdgeInsets {
        StackListGroupBoxContentInsetsKey.defaultValue
    }

    public static var contentSpacing: CGFloat {
        StackListGroupBoxContentSpacingKey.defaultValue
    }

    public static func contentInsets(scaledBy scale: CGFloat) -> EdgeInsets {
        let base = contentInsets
        return EdgeInsets(
            top: base.top * scale,
            leading: base.leading * scale,
            bottom: base.bottom * scale,
            trailing: base.trailing * scale
        )
    }
}

public enum StackListGroupBoxStyleOption {
    case automatic
    case plain
    case grouped
    case clear
}

private struct StackListGroupBoxContainer<Content: View>: View {
    @Environment(\.stackListBackgroundColorOverride) private var backgroundOverride
    @Environment(\.stackListGroupBoxContentInsets) private var contentInsets
    let defaultColor: Color
    let isGroupedContext: Bool
    let content: Content

    init(defaultColor: Color, isGroupedContext: Bool, @ViewBuilder content: () -> Content) {
        self.defaultColor = defaultColor
        self.isGroupedContext = isGroupedContext
        self.content = content()
    }

    var body: some View {
        content
            .padding(contentInsets)
            .background(
                RoundedRectangle(cornerRadius: stackListCornerRadius, style: .continuous)
                    .fill(backgroundOverride ?? defaultColor)
            )
            .contentShape(RoundedRectangle(cornerRadius: stackListCornerRadius, style: .continuous))
            .environment(\.stackSectionListContainedInGroupBox, true)
            .environment(\.stackListIsGroupedContext, isGroupedContext)
    }
}

public struct PlainStackListGroupBoxStyle: GroupBoxStyle {
    @Environment(\.stackListGroupBoxContentSpacing) private var contentSpacing

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        StackListGroupBoxContainer(defaultColor: Color.stackListCardBackgroundPlain, isGroupedContext: false) {
            VStack(alignment: .leading, spacing: contentSpacing) {
                configuration.label
                configuration.content
            }
        }
    }
}

public struct GroupedStackListGroupBoxStyle: GroupBoxStyle {
    @Environment(\.stackListGroupBoxContentSpacing) private var contentSpacing

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        StackListGroupBoxContainer(defaultColor: Color.stackListCardBackgroundGrouped, isGroupedContext: true) {
            VStack(alignment: .leading, spacing: contentSpacing) {
                configuration.label
                configuration.content
            }
        }
    }
}

public struct ClearStackListGroupBoxStyle: GroupBoxStyle {
    @Environment(\.stackListGroupBoxContentSpacing) private var contentSpacing

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configurationContent(configuration)
            .environment(\.stackSectionListContainedInGroupBox, true)
            .environment(\.stackListIsGroupedContext, false)
    }

    @ViewBuilder
    private func configurationContent(_ configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: contentSpacing) {
            configuration.label
            configuration.content
        }
    }
}

public extension GroupBoxStyle where Self == PlainStackListGroupBoxStyle {
    static var stackList: Self { Self() }
}

public extension GroupBoxStyle where Self == GroupedStackListGroupBoxStyle {
    static var groupedStackList: Self { Self() }
}

public extension GroupBoxStyle where Self == ClearStackListGroupBoxStyle {
    static var clearStackList: Self { Self() }
}

public extension View {
    @ViewBuilder
    public func applyStackListGroupBoxStyle(isGrouped: Bool) -> some View {
        applyStackListGroupBoxStyle(.automatic, defaultIsGrouped: isGrouped)
    }

    @ViewBuilder
    public func applyStackListGroupBoxStyle(_ appearance: StackListGroupBoxStyleOption, defaultIsGrouped: Bool = false) -> some View {
        switch appearance {
        case .automatic:
            if defaultIsGrouped {
                self.groupBoxStyle(.groupedStackList)
                    .environment(\.stackListStyle, .grouped)
            } else {
                self.groupBoxStyle(.stackList)
                    .environment(\.stackListStyle, .plain)
            }
        case .plain:
            self.groupBoxStyle(.stackList)
                .environment(\.stackListStyle, .plain)
        case .grouped:
            self.groupBoxStyle(.groupedStackList)
                .environment(\.stackListStyle, .grouped)
        case .clear:
            self.groupBoxStyle(.clearStackList)
                .environment(\.stackListStyle, .plain)
        }
    }

    public func stackListGroupBoxContentSpacing(_ value: CGFloat) -> some View {
        environment(\.stackListGroupBoxContentSpacing, value)
    }

    public func stackListGroupBoxContentInsets(_ value: EdgeInsets) -> some View {
        environment(\.stackListGroupBoxContentInsets, value)
    }
}
