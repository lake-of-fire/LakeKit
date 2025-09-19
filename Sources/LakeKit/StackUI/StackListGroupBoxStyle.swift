import SwiftUI

private let stackListCornerRadius: CGFloat = 20

private struct StackListBackgroundColorOverrideKey: EnvironmentKey {
    static let defaultValue: Color? = nil
}

private struct StackListIsGroupedContextKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var stackListBackgroundColorOverride: Color? {
        get { self[StackListBackgroundColorOverrideKey.self] }
        set { self[StackListBackgroundColorOverrideKey.self] = newValue }
    }

    var stackListIsGroupedContext: Bool {
        get { self[StackListIsGroupedContextKey.self] }
        set { self[StackListIsGroupedContextKey.self] = newValue }
    }
}

private struct StackListGroupBoxContainer<Content: View>: View {
    @Environment(\.stackListBackgroundColorOverride) private var backgroundOverride
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
            .padding(16)
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
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        StackListGroupBoxContainer(defaultColor: Color.stackListCardBackgroundPlain, isGroupedContext: false) {
            VStack(alignment: .leading, spacing: 12) {
                configuration.label
                configuration.content
            }
        }
    }
}

public struct GroupedStackListGroupBoxStyle: GroupBoxStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        StackListGroupBoxContainer(defaultColor: Color.stackListCardBackgroundGrouped, isGroupedContext: true) {
            VStack(alignment: .leading, spacing: 12) {
                configuration.label
                configuration.content
            }
        }
    }
}

public extension GroupBoxStyle where Self == PlainStackListGroupBoxStyle {
    static var stackList: Self { Self() }
}

public extension GroupBoxStyle where Self == GroupedStackListGroupBoxStyle {
    static var groupedStackList: Self { Self() }
}

public extension View {
    @ViewBuilder
    func applyStackListGroupBoxStyle(isGrouped: Bool) -> some View {
        if isGrouped {
            self
                .groupBoxStyle(.groupedStackList)
                .environment(\.stackListStyle, .grouped)
        } else {
            self
                .groupBoxStyle(.stackList)
                .environment(\.stackListStyle, .plain)
        }
    }
}
