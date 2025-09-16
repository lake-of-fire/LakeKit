import SwiftUI

public struct StackSectionListRow: Identifiable {
    public let id = UUID()
    public let content: AnyView
    public var separatorVisibility: Visibility
    
    public init<V: View>(content: V, separatorVisibility: Visibility = .automatic) {
        self.content = AnyView(content)
        self.separatorVisibility = separatorVisibility
    }
}

@resultBuilder
public enum StackSectionListBuilder {
    public static func buildBlock(_ components: [StackSectionListRow]...) -> [StackSectionListRow] {
        components.flatMap { $0 }
    }
    public static func buildExpression(_ expression: StackSectionListRow) -> [StackSectionListRow] {
        [expression]
    }
    public static func buildExpression(_ expression: EmptyView) -> [StackSectionListRow] {
        []
    }
    public static func buildExpression<V: View>(_ expression: V) -> [StackSectionListRow] {
        [StackSectionListRow(content: expression)]
    }
    public static func buildEither(first component: [StackSectionListRow]) -> [StackSectionListRow] { component }
    public static func buildEither(second component: [StackSectionListRow]) -> [StackSectionListRow] { component }
    public static func buildOptional(_ component: [StackSectionListRow]?) -> [StackSectionListRow] { component ?? [] }
    public static func buildArray(_ components: [[StackSectionListRow]]) -> [StackSectionListRow] {
        components.flatMap { $0 }
    }
}

public extension View {
    func stackSectionListRowSeparator(_ visibility: Visibility) -> StackSectionListRow {
        StackSectionListRow(content: self, separatorVisibility: visibility)
    }
}

public struct StackSectionList: View {
    private let rows: [StackSectionListRow]
    private let rowSpacing: CGFloat
    private let dividerInsets: EdgeInsets
    
    public init(
        rowSpacing: CGFloat = 0,
        dividerInsets: EdgeInsets = EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 0),
        @StackSectionListBuilder content: () -> [StackSectionListRow]
    ) {
        self.rows = content()
        self.rowSpacing = rowSpacing
        self.dividerInsets = dividerInsets
    }
    
    public var body: some View {
        VStack(spacing: rowSpacing) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                row.content
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                if shouldShowDivider(after: index) {
                    Divider()
                        .padding(dividerInsets)
                }
            }
        }
    }
    
    private func shouldShowDivider(after index: Int) -> Bool {
        guard index < rows.count - 1 else { return false }
        let currentVisibility = rows[index].separatorVisibility
        let nextVisibility = rows[index + 1].separatorVisibility
        return allowsDivider(currentVisibility) && allowsDivider(nextVisibility)
    }
    
    private func allowsDivider(_ visibility: Visibility) -> Bool {
        switch visibility {
        case .hidden:
            return false
        case .visible, .automatic:
            return true
        @unknown default:
            return true
        }
    }
}
