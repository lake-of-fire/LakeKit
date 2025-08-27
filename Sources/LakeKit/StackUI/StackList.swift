import SwiftUI

// MARK: - StackList Style & Environment

public struct StackListStyle: Equatable {
    public var interItemSpacing: CGFloat
    public var managesSeparators: Bool
    public var expandedBottomPadding: CGFloat
    
    public init(
        interItemSpacing: CGFloat = 26,
        managesSeparators: Bool = true,
        expandedBottomPadding: CGFloat = 0
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

// Publish expansion state per row (used only to gate animations)
struct StackListRowExpansionPreferenceKey: PreferenceKey {
    static var defaultValue: [UUID: Bool] = [:]
    static func reduce(value: inout [UUID: Bool], nextValue: () -> [UUID: Bool]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

// MARK: - Unified row preference payload (coalesce all row prefs into a single key)
struct StackListRowPrefs: Equatable {
    var isEmpty: Bool?
    var height: CGFloat?
    var isExpanded: Bool?
    var separatorOverride: Visibility?
}

struct StackListRowPrefsPreferenceKey: PreferenceKey {
    static var defaultValue: [UUID: StackListRowPrefs] = [:]
    static func reduce(value: inout [UUID: StackListRowPrefs], nextValue: () -> [UUID: StackListRowPrefs]) {
        for (k, v) in nextValue() {
            var current = value[k] ?? StackListRowPrefs()
            if let e = v.isEmpty { current.isEmpty = e }
            if let h = v.height { current.height = h }
            if let ex = v.isExpanded { current.isExpanded = ex }
            if let s = v.separatorOverride { current.separatorOverride = s }
            value[k] = current
        }
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
#if os(iOS)
                let scale = UIScreen.main.scale
#elseif os(macOS)
                let scale = NSScreen.main?.backingScaleFactor ?? 2
#else
                let scale: CGFloat = 2
#endif
                let rawH = proxy.size.height
                // Quantize to device pixels to avoid tiny float jitter causing feedback loops
                let qH = (rawH * scale).rounded(.toNearestOrEven) / scale
                let heightForPrefs = qH < (1 / scale) ? 0 : qH
                
                Color.clear
                    .preference(
                        key: StackListRowPrefsPreferenceKey.self,
                        value: [rowID: StackListRowPrefs(
                            isEmpty: (heightForPrefs <= 0.5 || proxy.size.width <= 0.5),
                            height: heightForPrefs,
                            isExpanded: nil,
                            separatorOverride: nil
                        )]
                    )
            }
                .transaction { t in t.disablesAnimations = true }
        )
    }
}

public struct StackList: View {
    private let style: StackListStyle
    private let rows: [StackListRowItem]
    
    @State private var rowSeparatorOverrides: [UUID: Visibility] = [:]
    @State private var rowIsEmpty: [UUID: Bool] = [:]
    @State private var rowHeights: [UUID: CGFloat] = [:]
    @State private var rowExpanded: [UUID: Bool] = [:]
    @State private var animateRows: Set<UUID> = []
    
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
            let lastRowID = rows.last?.id
            ForEach(rows, id: \.id) { row in
                let rowID = row.id
                let isLastRow = (rowID == lastRowID)
                let isRowEmpty = rowIsEmpty[rowID] ?? false
                let hasSeparator = style.managesSeparators && !isLastRow && !isRowEmpty && (rowSeparatorOverrides[rowID] ?? row.separatorVisibility) != .hidden
                
                StackListRowHost(rowID: rowID, content: row.view)
                    .environment(\.stackListRowID, rowID)
                    .frame(height: rowHeights[rowID], alignment: .top)
                
                if !isLastRow && !isRowEmpty {
                    ZStack(alignment: .center) {
                        Color.clear.frame(height: style.interItemSpacing)
                        if hasSeparator {
                            Divider()
                                .padding(.vertical, style.interItemSpacing / 2)
                        }
                    }
                    .transaction { t in t.disablesAnimations = true }
                }
            }
        }
        .onPreferenceChange(StackListRowPrefsPreferenceKey.self) { newValue in
            DispatchQueue.main.async {
                // 1) Next snapshots for non-animated state
                var nextEmpty = rowIsEmpty
                var nextOverrides = rowSeparatorOverrides
                var nextExpanded = rowExpanded
                
                for (id, prefs) in newValue {
                    if let e = prefs.isEmpty { nextEmpty[id] = e }
                    if let s = prefs.separatorOverride { nextOverrides[id] = s }
                    if let ex = prefs.isExpanded { nextExpanded[id] = ex }
                }
                
                // Detect which rows toggled expansion this pass
                var toggled: Set<UUID> = []
                let allKeys = Set(rowExpanded.keys).union(nextExpanded.keys)
                for id in allKeys {
                    if rowExpanded[id] != nextExpanded[id] { toggled.insert(id) }
                }
                
                // 2) Heights: split into non-animated vs animated commits
                var nextNonAnimatedHeights = rowHeights
                var nextAllHeights = rowHeights
                var hasAnimatedChange = false
                
#if os(iOS)
                let eps: CGFloat = 1 / UIScreen.main.scale
#elseif os(macOS)
                let eps: CGFloat = 1 / (NSScreen.main?.backingScaleFactor ?? 2)
#else
                let eps: CGFloat = 0.5
#endif
                for (id, prefs) in newValue {
                    if let h = prefs.height {
                        let old = rowHeights[id]
                        // Only react if change exceeds 1 pixel to avoid oscillations
                        if old == nil || abs((old ?? 0) - h) >= eps {
                            if toggled.contains(id) {
                                nextAllHeights[id] = h
                                hasAnimatedChange = true
                            } else {
                                nextNonAnimatedHeights[id] = h
                                nextAllHeights[id] = h
                            }
                        }
                    }
                }
                
                // 3) Commit: non-animated base state (only if changed)
                let baseChanged = (nextEmpty != rowIsEmpty)
                || (nextOverrides != rowSeparatorOverrides)
                || (nextExpanded != rowExpanded)
                || (animateRows != toggled)
                if baseChanged {
                    withTransaction(Transaction(animation: nil)) {
                        if nextEmpty != rowIsEmpty { rowIsEmpty = nextEmpty }
                        if nextOverrides != rowSeparatorOverrides { rowSeparatorOverrides = nextOverrides }
                        if nextExpanded != rowExpanded { rowExpanded = nextExpanded }
                        if animateRows != toggled { animateRows = toggled }
                    }
                }
                
                // 4) Commit: heights (non-animated pass)
                if nextNonAnimatedHeights != rowHeights {
                    withTransaction(Transaction(animation: nil)) {
                        rowHeights = nextNonAnimatedHeights
                    }
                }
                
                // 5) Commit: heights (animated pass if needed)
                if hasAnimatedChange {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        rowHeights = nextAllHeights
                    }
                }
                
                // 6) Clear animation gating (only if non-empty)
                if !animateRows.isEmpty {
                    withTransaction(Transaction(animation: nil)) {
                        animateRows.removeAll()
                    }
                }
            }
        }
        .environment(\.stackListStyle, style)
        .frame(maxWidth: 850)
    }
}
