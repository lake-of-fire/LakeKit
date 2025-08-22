import SwiftUI

// MARK: - StackList Style & Environment

public struct StackListStyle: Equatable {
    public var interItemSpacing: CGFloat
    public var managesSeparators: Bool
    
    public init(
        interItemSpacing: CGFloat = 0,
        managesSeparators: Bool = true
    ) {
        self.interItemSpacing = interItemSpacing
        self.managesSeparators = managesSeparators
    }
}

private struct StackListStyleKey: EnvironmentKey {
    static let defaultValue = StackListStyle()
}

extension EnvironmentValues {
    var stackListStyle: StackListStyle {
        get { self[StackListStyleKey.self] }
        set { self[StackListStyleKey.self] = newValue }
    }
}

// MARK: - Row item & result builder

public struct StackListRowItem: Identifiable {
    public let id = UUID()
    public let view: AnyView
    public var separatorVisibility: Visibility
    
    public init<V: View>(view: V, separatorVisibility: Visibility = .automatic) {
        self.view = AnyView(view)
        self.separatorVisibility = separatorVisibility
    }
}

@resultBuilder
public enum StackListBuilder {
    public static func buildBlock(_ components: [StackListRowItem]...) -> [StackListRowItem] {
        components.flatMap { $0 }
    }
    public static func buildExpression(_ expression: StackListRowItem) -> [StackListRowItem] {
        [expression]
    }
    public static func buildExpression<V: View>(_ expression: V) -> [StackListRowItem] {
        [StackListRowItem(view: expression, separatorVisibility: .automatic)]
    }
    public static func buildExpression<H: View, C: View>(_ expression: StackSection<H, C>) -> [StackListRowItem] {
        [StackListRowItem(view: expression, separatorVisibility: expression.stackListDefaultSeparatorVisibility())]
    }
    public static func buildEither(first component: [StackListRowItem]) -> [StackListRowItem] { component }
    public static func buildEither(second component: [StackListRowItem]) -> [StackListRowItem] { component }
    public static func buildOptional(_ component: [StackListRowItem]?) -> [StackListRowItem] { component ?? [] }
    public static func buildArray(_ components: [[StackListRowItem]]) -> [StackListRowItem] {
        components.flatMap { $0 }
    }
}

// MARK: - Row-scoped modifier API, like List's .listRowSeparator

public extension View {
    /// Row-scoped API mirroring SwiftUI's `.listRowSeparator(_:)`, but for `StackList`.
    func stackListRowSeparator(_ visibility: Visibility) -> StackListRowItem {
        StackListRowItem(view: self, separatorVisibility: visibility)
    }
}

public struct StackList<Content: View>: View {
    @ViewBuilder private let content: () -> Content
    private let style: StackListStyle
    private let rowsBuilder: (() -> [StackListRowItem])?
    
    public init(@ViewBuilder content: @escaping () -> Content) {
        self.style = StackListStyle()
        self.rowsBuilder = nil
        self.content = content
    }
    
    public init(style: StackListStyle, @ViewBuilder content: @escaping () -> Content) {
        self.style = style
        self.rowsBuilder = nil
        self.content = content
    }
    
    public init(@StackListBuilder rows: @escaping () -> [StackListRowItem]) {
        self.style = StackListStyle()
        self.rowsBuilder = rows
        self.content = { EmptyView() as! Content }
    }
    
    public init(style: StackListStyle, @StackListBuilder rows: @escaping () -> [StackListRowItem]) {
        self.style = style
        self.rowsBuilder = rows
        self.content = { EmptyView() as! Content }
    }
    
    public var body: some View {
        Group {
            if let rowsBuilder {
                let rows = rowsBuilder()
                VStack(alignment: .leading, spacing: style.interItemSpacing) {
                    ForEach(Array(rows.enumerated()), id: \.0) { index, row in
                        row.view
                        if style.managesSeparators, index < rows.count - 1 {
                            if row.separatorVisibility != .hidden {
                                Divider()
                            }
                        }
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: style.interItemSpacing) {
                    content()
                }
            }
        }
        .environment(\.stackListStyle, style)
        .frame(maxWidth: 850)
    }
}
