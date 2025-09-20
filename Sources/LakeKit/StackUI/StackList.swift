import SwiftUI

// MARK: - StackList Style & Environment

public struct StackListConfig: Equatable {
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

private struct StackListConfigKey: EnvironmentKey {
    static let defaultValue = StackListConfig()
}

extension EnvironmentValues {
    var stackListConfig: StackListConfig {
        get { self[StackListConfigKey.self] }
        set { self[StackListConfigKey.self] = newValue }
    }
}

// MARK: - Appearance Environment (separate from layout config)
public enum StackListAppearance: Equatable {
    case automatic
    case plain
    case grouped
}

private struct StackListAppearanceKey: EnvironmentKey {
    static let defaultValue: StackListAppearance = .plain
}

extension EnvironmentValues {
    public var stackListStyle: StackListAppearance {
        get { self[StackListAppearanceKey.self] }
        set { self[StackListAppearanceKey.self] = newValue }
    }
}

private struct StackListContentBackgroundVisibilityKey: EnvironmentKey {
    static let defaultValue: Visibility = .automatic
}

extension EnvironmentValues {
    public var stackListContentBackgroundVisibility: Visibility {
        get { self[StackListContentBackgroundVisibilityKey.self] }
        set { self[StackListContentBackgroundVisibilityKey.self] = newValue }
    }
}

// MARK: - Style-type API (mimic SwiftUI's .listStyle)

public protocol StackListAppearanceStyle { }

public struct PlainStackListStyle: StackListAppearanceStyle {
    public init() {}
}

public struct GroupedStackListStyle: StackListAppearanceStyle {
    public init() {}
}

public extension StackListAppearanceStyle where Self == PlainStackListStyle {
    static var plain: Self { .init() }
}

public extension StackListAppearanceStyle where Self == GroupedStackListStyle {
    static var grouped: Self { .init() }
}

private struct StackListStyleTypeModifier<S: StackListAppearanceStyle>: ViewModifier {
    let style: S
    func body(content: Content) -> some View {
        let appearance: StackListAppearance = (style is PlainStackListStyle) ? .plain : .grouped
        return content.environment(\.stackListStyle, appearance)
    }
}

public extension View {
    /// Mirrors SwiftUI's `.listStyle(...)` generic API (e.g., `.stackListStyle(.plain)` / `.stackListStyle(.grouped)`).
    func stackListStyle<S>(_ style: S) -> some View where S: StackListAppearanceStyle {
        modifier(StackListStyleTypeModifier(style: style))
    }
    /// Convenience overload: Set the appearance directly via enum.
    func stackListStyle(_ appearance: StackListAppearance) -> some View {
        environment(\.stackListStyle, appearance)
    }
    /// Matches SwiftUI's `.scrollContentBackground(_:)`, allowing callers to show or hide StackList's background.
    func stackListContentBackground(_ visibility: Visibility) -> some View {
        environment(\.stackListContentBackgroundVisibility, visibility)
    }
}

private struct StackListStyleWriter: ViewModifier {
    @Environment(\.stackListConfig) private var current
    let interItemSpacing: CGFloat?
    let managesSeparators: Bool?
    let expandedBottomPadding: CGFloat?
    
    func body(content: Content) -> some View {
        var next = current
        if let s = interItemSpacing { next.interItemSpacing = s }
        if let m = managesSeparators { next.managesSeparators = m }
        if let p = expandedBottomPadding { next.expandedBottomPadding = p }
        return content.environment(\.stackListConfig, next)
    }
}

public extension View {
    func stackListInterItemSpacing(_ value: CGFloat) -> some View {
        modifier(StackListStyleWriter(interItemSpacing: value, managesSeparators: nil, expandedBottomPadding: nil))
    }
    func stackListManagesSeparators(_ value: Bool) -> some View {
        modifier(StackListStyleWriter(interItemSpacing: nil, managesSeparators: value, expandedBottomPadding: nil))
    }
    func stackListExpandedBottomPadding(_ value: CGFloat) -> some View {
        modifier(StackListStyleWriter(interItemSpacing: nil, managesSeparators: nil, expandedBottomPadding: value))
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
    @Environment(\.stackListConfig) private var config
    @Environment(\.stackListStyle) private var appearance
    @Environment(\.stackListContentBackgroundVisibility) private var contentBackgroundVisibility
    @State private var rows: [StackListRowItem]
    
    @State private var rowSeparatorOverrides: [UUID: Visibility] = [:]
    @State private var rowIsEmpty: [UUID: Bool] = [:]
    @State private var rowHeights: [UUID: CGFloat] = [:]
    @State private var rowExpanded: [UUID: Bool] = [:]
    @State private var animateRows: Set<UUID> = []
    
    public init(@StackListBuilder rows: () -> [StackListRowItem]) {
        self._rows = State(initialValue: rows())
    }
    
    public var body: some View {
        if appearance == .grouped {
            contentWithBackground(defaultColor: Color.systemGroupedBackground)
                .groupBoxStyle(.groupedStackList)
        } else {
            contentWithBackground(defaultColor: Color.systemBackground)
                .groupBoxStyle(.stackList)
        }
    }

    @ViewBuilder
    private func contentWithBackground(defaultColor: Color) -> some View {
        if let backgroundColor = resolvedContentBackgroundColor(defaultColor: defaultColor) {
            scrollContent
                .background(backgroundColor)
        } else {
            scrollContent
        }
    }

    private var scrollContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                let firstRowID = rows.first?.id
                let lastRowID = rows.last?.id
                ForEach(rows, id: \.id) { row in
                    let rowID = row.id
                    let isFirstRow = (rowID == firstRowID)
                    let isLastRow = (rowID == lastRowID)
                    let isRowEmpty = rowIsEmpty[rowID] ?? false
                    let hasSeparator = config.managesSeparators && !isLastRow && !isRowEmpty && (rowSeparatorOverrides[rowID] ?? row.separatorVisibility) != .hidden
                    let clampedHeight: CGFloat? = animateRows.contains(rowID) ? rowHeights[rowID] : nil
                    
                    StackListRowHost(rowID: rowID, content: row.view)
                        .environment(\.stackListRowID, rowID)
                        .frame(height: clampedHeight, alignment: .top)
                        .padding(.top, isFirstRow ? config.interItemSpacing / 2 : 0)
                    
                    if !isLastRow && !isRowEmpty {
                        ZStack(alignment: .center) {
                            Color.clear.frame(height: config.interItemSpacing)
                            if hasSeparator {
                                Divider()
                                    .padding(.vertical, config.interItemSpacing / 2)
                            }
                        }
                        .transaction { t in t.disablesAnimations = true }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(maxWidth: 850)
            .frame(maxWidth: .infinity, alignment: .center)
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
        }
    }
    
    private func resolvedContentBackgroundColor(defaultColor: Color) -> Color? {
        switch contentBackgroundVisibility {
        case .hidden:
            return nil
        case .visible, .automatic:
            return defaultColor
        @unknown default:
            return defaultColor
        }
    }
}
