import SwiftUI

// MARK: - StackList Style & Environment

public struct StackListStyle: Equatable {
    public var interItemSpacing: CGFloat
    public var managesSeparators: Bool
    public var expandedBottomPadding: CGFloat
    public var dividerVerticalPadding: CGFloat
    
    public init(
        interItemSpacing: CGFloat = 8,
        managesSeparators: Bool = true,
        expandedBottomPadding: CGFloat = 10,
        dividerVerticalPadding: CGFloat = 6
    ) {
        self.interItemSpacing = interItemSpacing
        self.managesSeparators = managesSeparators
        self.expandedBottomPadding = expandedBottomPadding
        self.dividerVerticalPadding = dividerVerticalPadding
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

// MARK: - Row identity & dynamic separator prefs (internal)
private struct StackListRowIDKey: EnvironmentKey {
    static let defaultValue: UUID? = nil
}
extension EnvironmentValues {
    var stackListRowID: UUID? {
        get { self[StackListRowIDKey.self] }
        set { self[StackListRowIDKey.self] = newValue }
    }
}
struct StackListRowSeparatorPreferenceKey: PreferenceKey {
    static var defaultValue: [UUID: Visibility] = [:]
    static func reduce(value: inout [UUID: Visibility], nextValue: () -> [UUID: Visibility]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
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
    public static func buildExpression<H: View, C: View>(_ expression: StackSection<H, C>) -> [StackListRowItem] {
        [StackListRowItem(view: expression, separatorVisibility: expression.stackListDefaultSeparatorVisibility())]
    }
    public static func buildExpression<V: View>(_ expression: V) -> [StackListRowItem] {
        [StackListRowItem(view: expression, separatorVisibility: .automatic)]
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
    private let rows: [StackListRowItem]?
    
    @State private var rowSeparators: [UUID: Visibility] = [:]
    
    public init(@ViewBuilder content: @escaping () -> Content) {
        self.style = StackListStyle()
        self.rows = nil
        self.content = content
    }
    
    public init(style: StackListStyle, @ViewBuilder content: @escaping () -> Content) {
        self.style = style
        self.rows = nil
        self.content = content
    }
    
    public init(rows: @StackListBuilder () -> [StackListRowItem]) {
        self.style = StackListStyle()
        self.rows = rows()
        self.content = { EmptyView() as! Content }
    }
    
    public init(style: StackListStyle, rows: @StackListBuilder () -> [StackListRowItem]) {
        self.style = style
        self.rows = rows()
        self.content = { EmptyView() as! Content }
    }
    
    public var body: some View {
        Group {
            if let rows {
                VStack(alignment: .leading, spacing: style.interItemSpacing) {
                    ForEach(Array(rows.enumerated()), id: \.0) { index, row in
                        let rowID = row.id
                        row.view
                            .environment(\.stackListRowID, rowID)
                        // Provide a static default; children (e.g., StackSection) can override via preference.
                            .preference(key: StackListRowSeparatorPreferenceKey.self,
                                        value: [rowID: row.separatorVisibility])
                        if style.managesSeparators, index < rows.count - 1 {
                            let visibility = rowSeparators[rowID] ?? row.separatorVisibility
                            if visibility != .hidden {
                                Divider()
                                    .padding(.vertical, style.dividerVerticalPadding)
                            }
                        }
                    }
                }
                .onPreferenceChange(StackListRowSeparatorPreferenceKey.self) { rowSeparators = $0 }
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
