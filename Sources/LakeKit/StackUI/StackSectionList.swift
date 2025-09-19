import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct StackSectionListBadgeValueKey: EnvironmentKey {
    static let defaultValue: Int? = nil
}

extension EnvironmentValues {
    var stackSectionListBadgeValue: Int? {
        get { self[StackSectionListBadgeValueKey.self] }
        set { self[StackSectionListBadgeValueKey.self] = newValue }
    }
}

private struct StackSectionListContainedInGroupBoxKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var stackSectionListContainedInGroupBox: Bool {
        get { self[StackSectionListContainedInGroupBoxKey.self] }
        set { self[StackSectionListContainedInGroupBoxKey.self] = newValue }
    }
}

public struct StackSectionListRow: Identifiable {
    public let id = UUID()
    public let content: AnyView
    public var separatorVisibility: Visibility
    public var badgeValue: Int?
    public var dividerLeadingInset: CGFloat?
    
    public init<V: View>(
        content: V,
        separatorVisibility: Visibility = .automatic,
        badgeValue: Int? = nil,
        dividerLeadingInset: CGFloat? = nil
    ) {
        self.content = AnyView(content)
        self.separatorVisibility = separatorVisibility
        self.badgeValue = badgeValue
        self.dividerLeadingInset = dividerLeadingInset
    }
}

public struct StackSectionListRowContent<Content: View> {
    fileprivate var content: Content
    fileprivate var separatorVisibility: Visibility
    fileprivate var badgeValue: Int?
    fileprivate var dividerLeadingInset: CGFloat?
    
    public init(
        content: Content,
        separatorVisibility: Visibility = .automatic,
        badgeValue: Int? = nil,
        dividerLeadingInset: CGFloat? = nil
    ) {
        self.content = content
        self.separatorVisibility = separatorVisibility
        self.badgeValue = badgeValue
        self.dividerLeadingInset = dividerLeadingInset
    }
    
    fileprivate func makeRow() -> StackSectionListRow {
        StackSectionListRow(
            content: content,
            separatorVisibility: separatorVisibility,
            badgeValue: badgeValue,
            dividerLeadingInset: dividerLeadingInset
        )
    }
}

public extension StackSectionListRowContent {
    func badge(_ value: Int?) -> StackSectionListRowContent {
        var copy = self
        copy.badgeValue = value
        return copy
    }
    
    func stackSectionListDividerLeadingInset(_ value: CGFloat?) -> StackSectionListRowContent {
        var copy = self
        copy.dividerLeadingInset = value
        return copy
    }
    
    func stackSectionListRowSeparator(_ visibility: Visibility) -> StackSectionListRowContent {
        var copy = self
        copy.separatorVisibility = visibility
        return copy
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
    public static func buildExpression(_ expression: [StackSectionListRow]) -> [StackSectionListRow] {
        expression
    }
    public static func buildExpression<Content>(_ expression: StackSectionListRowContent<Content>) -> [StackSectionListRow] where Content: View {
        [expression.makeRow()]
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
    func stackSectionListRow(separatorVisibility: Visibility = .automatic) -> StackSectionListRowContent<Self> {
        StackSectionListRowContent(content: self, separatorVisibility: separatorVisibility)
    }
    @_disfavoredOverload
    func badge(_ value: Int?) -> StackSectionListRowContent<Self> {
        stackSectionListRow().badge(value)
    }
    func stackSectionListDividerLeadingInset(_ value: CGFloat?) -> StackSectionListRowContent<Self> {
        stackSectionListRow().stackSectionListDividerLeadingInset(value)
    }
    func stackSectionListRowSeparator(_ visibility: Visibility) -> StackSectionListRowContent<Self> {
        stackSectionListRow(separatorVisibility: visibility)
    }
}

public extension StackSectionListRow {
    func badge(_ value: Int?) -> StackSectionListRow {
        StackSectionListRow(
            content: content,
            separatorVisibility: separatorVisibility,
            badgeValue: value,
            dividerLeadingInset: dividerLeadingInset
        )
    }
    
    func stackSectionListDividerLeadingInset(_ value: CGFloat?) -> StackSectionListRow {
        StackSectionListRow(
            content: content,
            separatorVisibility: separatorVisibility,
            badgeValue: badgeValue,
            dividerLeadingInset: value
        )
    }
}

public struct StackSectionList: View {
    private let rows: [StackSectionListRow]
    private let rowSpacing: CGFloat
    private let dividerInsets: EdgeInsets
    @Environment(\.stackSectionListContainedInGroupBox) private var isContainedInGroupBox
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
                let baseRow = AnyView(
                    row.content
                        .environment(\.stackSectionListBadgeValue, row.badgeValue)
                )
                let rowView: AnyView = {
                    if isContainedInGroupBox {
                        return baseRow
                    } else {
                        return AnyView(baseRow.stackSectionListDefaultEmphasis())
                    }
                }()
                rowView
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                if shouldShowDivider(after: index) {
                    Divider()
                        .padding(.top, dividerInsets.top)
                        .padding(.bottom, dividerInsets.bottom)
                        .padding(.leading, row.dividerLeadingInset ?? dividerInsets.leading)
                        .padding(.trailing, dividerInsets.trailing)
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

private extension View {
    @ViewBuilder
    func stackSectionListDefaultEmphasis() -> some View {
        if #available(iOS 16, macOS 13, *) {
            self.fontWeight(.semibold)
        } else {
            self.font(.system(size: StackSectionListTypography.bodyPointSize, weight: .semibold))
        }
    }
}

private enum StackSectionListTypography {
    static var bodyPointSize: CGFloat {
#if os(iOS)
        UIFont.preferredFont(forTextStyle: .body).pointSize
#elseif os(macOS)
        NSFont.preferredFont(forTextStyle: .body).pointSize
#else
        17
#endif
    }
}
