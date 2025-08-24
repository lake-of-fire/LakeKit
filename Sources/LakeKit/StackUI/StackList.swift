import SwiftUI

// MARK: - StackList Style & Environment

public struct StackListStyle: Equatable {
    public var interItemSpacing: CGFloat
    public var managesSeparators: Bool
    public var expandedBottomPadding: CGFloat
    
    public init(
        interItemSpacing: CGFloat = 26,
        managesSeparators: Bool = true,
        expandedBottomPadding: CGFloat = 8
    ) {
        self.interItemSpacing = interItemSpacing
        self.managesSeparators = managesSeparators
        self.expandedBottomPadding = expandedBottomPadding
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
// Parent publishes a default per row; children (e.g., StackSection) may override dynamically.
struct StackListRowSeparatorDefaultPreferenceKey: PreferenceKey {
    static var defaultValue: [UUID: Visibility] = [:]
    static func reduce(value: inout [UUID: Visibility], nextValue: () -> [UUID: Visibility]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}
struct StackListRowSeparatorOverridePreferenceKey: PreferenceKey {
    static var defaultValue: [UUID: Visibility] = [:]
    static func reduce(value: inout [UUID: Visibility], nextValue: () -> [UUID: Visibility]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

// Detect if a row renders as empty (zero-size)
struct StackListRowEmptyPreferenceKey: PreferenceKey {
    static var defaultValue: [UUID: Bool] = [:]
    static func reduce(value: inout [UUID: Bool], nextValue: () -> [UUID: Bool]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

// Publish measured height per row (animates any content-driven height change)
struct StackListRowHeightPreferenceKey: PreferenceKey {
    static var defaultValue: [UUID: CGFloat] = [:]
    static func reduce(value: inout [UUID: CGFloat], nextValue: () -> [UUID: CGFloat]) {
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
    public static func buildExpression(_ expression: EmptyView) -> [StackListRowItem] {
        []
    }
    public static func buildExpression<V: View>(_ expression: V) -> [StackListRowItem] {
        // Non-StackSection rows default to no divider unless explicitly requested via .stackListRowSeparator(.automatic)
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

//public extension View {
//    func stackListRowHidden(_ hidden: Bool) -> StackListRowItem {
//        StackListRowItem(view: self, separatorVisibility: .automatic, isHidden: hidden)
//    }
//}

// A wrapper that guarantees preferences/geometry emit even if the row's view tree renders nothing.
private struct StackListRowHost: View {
    let rowID: UUID
    let content: AnyView
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            content
        }
        .background(
            GeometryReader { proxy in
                Color.clear
                    .preference(
                        key: StackListRowEmptyPreferenceKey.self,
                        value: [rowID: (proxy.size.height <= 0.5 || proxy.size.width <= 0.5)]
                    )
                    .preferredColorScheme(nil) // no-op to chain modifiers safely
                    .preference(
                        key: StackListRowHeightPreferenceKey.self,
                        value: [rowID: proxy.size.height]
                    )
            }
        )
    }
}

public struct StackList: View {
    private let style: StackListStyle
    private let rows: [StackListRowItem]
    
    @State private var rowSeparatorDefaults: [UUID: Visibility] = [:]
    @State private var rowSeparatorOverrides: [UUID: Visibility] = [:]
    @State private var rowIsEmpty: [UUID: Bool] = [:]
    @State private var rowHeights: [UUID: CGFloat] = [:]
    
    public init(@StackListBuilder rows: () -> [StackListRowItem]) {
        self.style = StackListStyle()
        self.rows = rows()
    }
    
    public init(style: StackListStyle, @StackListBuilder rows: () -> [StackListRowItem]) {
        self.style = style
        self.rows = rows()
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            let rowCount = rows.count
            ForEach(Array(rows.enumerated()), id: \.0) { index, row in
                let rowID = row.id
                
                let isLastRow = index == rows.count - 1
                let isRowEmpty = rowIsEmpty[rowID] ?? false
                 let hasSeparator = style.managesSeparators && !isLastRow && !isRowEmpty && (rowSeparatorOverrides[rowID] ?? rowSeparatorDefaults[rowID] ?? row.separatorVisibility) != .hidden
                
                StackListRowHost(rowID: rowID, content: row.view)
                    .environment(\.stackListRowID, rowID)
                    .preference(key: StackListRowSeparatorDefaultPreferenceKey.self,
                                value: [rowID: row.separatorVisibility])
                    .padding(.bottom, hasSeparator ? 0 : style.interItemSpacing)
                    .frame(
                        height: (rowHeights[rowID] ?? 0)
                        + ((isRowEmpty || hasSeparator || isLastRow) ? 0 : style.interItemSpacing),
                        alignment: .top
                    )
                    .overlay(alignment: .bottom) {
                        if hasSeparator {
                            Divider()
                                .padding(.bottom, style.interItemSpacing / 2)
                                .transition(.opacity)
                        }
                    }
            }
        }
        .onPreferenceChange(StackListRowSeparatorDefaultPreferenceKey.self) { newValue in
            if rowSeparatorDefaults != newValue {
                rowSeparatorDefaults = newValue
            }
        }
        .onPreferenceChange(StackListRowSeparatorOverridePreferenceKey.self) { newValue in
            if rowSeparatorOverrides != newValue {
                rowSeparatorOverrides = newValue
            }
        }
        .onPreferenceChange(StackListRowEmptyPreferenceKey.self) { newValue in
            if rowIsEmpty != newValue {
                rowIsEmpty = newValue
            }
        }
        .onPreferenceChange(StackListRowHeightPreferenceKey.self) { newValue in
            if rowHeights != newValue {
                withAnimation(.easeInOut(duration: 0.25)) {
                    rowHeights = newValue
                }
            }
        }
        .environment(\.stackListStyle, style)
        .animation(.easeInOut(duration: 0.25), value: rowSeparatorOverrides)
        .animation(nil, value: rowIsEmpty)
        .animation(nil, value: rowSeparatorDefaults)
        .animation(.easeInOut(duration: 0.25), value: rowHeights)
        .frame(maxWidth: 850)
    }
}
