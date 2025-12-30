import SwiftUI
import NavigationBackport

fileprivate enum StackSectionMetrics {
    static let headerRowSpacing: CGFloat = 8
    static let trailingIconHeaderRowSpacing: CGFloat = 6
    static let contentTopSpacing: CGFloat = 8
    // Provide extra horizontal room for the content mask so horizontal scrolling remains unclipped.
    static let contentMaskHorizontalOverflow: CGFloat = 1200
    static let trailingIconButtonSize: CGFloat = 32
}

public struct StackSection<Header: View, Content: View, NavigationValue: Hashable>: View {
    private enum Expansion { case toggleable(Binding<Bool>), alwaysExpanded }
    private let expansion: Expansion
    private let navigationValue: NavigationValue?
    @ViewBuilder private let header: () -> Header
    @ViewBuilder private let content: () -> Content
    @ViewBuilder private let trailingHeader: () -> AnyView
    @Environment(\.stackListRowID) private var stackListRowID
    
    // Default per-row separator policy for StackList builder
    public func stackListDefaultSeparatorVisibility() -> Visibility {
        switch expansion {
        case .alwaysExpanded:
            return .hidden
        case .toggleable(let isExpanded):
            return isExpanded.wrappedValue ? .hidden : .automatic
        }
    }
    
    public init(
        navigationValue: NavigationValue? = nil,
        isExpanded: Binding<Bool>,
        trailingHeader: @escaping () -> some View = { EmptyView() },
        @ViewBuilder header: @escaping () -> Header,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.expansion = .toggleable(isExpanded)
        self.navigationValue = navigationValue
        self.header = header
        self.content = content
        self.trailingHeader = { AnyView(trailingHeader()) }
    }
    
    public init(
        _ titleKey: LocalizedStringKey,
        navigationValue: NavigationValue? = nil,
        isExpanded: Binding<Bool>,
        trailingHeader: @escaping () -> some View = { EmptyView() },
        @ViewBuilder content: @escaping () -> Content
    ) where Header == Text {
        self.init(
            navigationValue: navigationValue,
            isExpanded: isExpanded,
            trailingHeader: trailingHeader,
            header: { Text(titleKey) },
            content: content)
    }
    
    public init(
        navigationValue: NavigationValue? = nil,
        @ViewBuilder header: @escaping () -> Header,
        trailingHeader: @escaping () -> some View = { EmptyView() },
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.expansion = .alwaysExpanded
        self.navigationValue = navigationValue
        self.header = header
        self.trailingHeader = { AnyView(trailingHeader()) }
        self.content = content
    }
    
    public init(
        _ titleKey: LocalizedStringKey,
        navigationValue: NavigationValue? = nil,
        trailingHeader: @escaping () -> some View = { EmptyView() },
        @ViewBuilder content: @escaping () -> Content
    ) where Header == Text {
        self.init(
            navigationValue: navigationValue,
            header: { Text(titleKey) },
            trailingHeader: trailingHeader,
            content: content)
    }

    @ViewBuilder
    private func wrappedHeader() -> some View {
        if let navigationValue {
            if #available(iOS 16, macOS 13, *) {
                NavigationLink(value: navigationValue) {
                    headerWithChevron()
                }
            } else {
                NBNavigationLink(value: navigationValue) {
                    headerWithChevron()
                }
            }
        } else {
            header()
        }
    }
    
    @ViewBuilder
    private func headerWithChevron() -> some View {
        HStack(spacing: 3) {
            header()
            headerChevron()
        }
    }
    
    @ViewBuilder
    private func headerChevron() -> some View {
        switch expansion {
        case .toggleable(let isExpanded):
            if navigationValue != nil,
               (Header.self == Text.self),
               isExpanded.wrappedValue {
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
                    .imageScale(.small)
            }
        default: EmptyView()
        }
    }
    
    @ViewBuilder
    public var body: some View {
        switch expansion {
        case .alwaysExpanded:
            VStack(alignment: .leading, spacing: StackSectionMetrics.contentTopSpacing) {
                HStack(alignment: .center, spacing: StackSectionMetrics.headerRowSpacing) {
                    wrappedHeader()
                        .modifier(SectionHeaderModifier())
                        .frame(maxWidth: .infinity, alignment: .leading)
                    trailingHeader()
                        .modifier(StackSectionTrailingHeaderModifier())
                }
                content()
            }
            .preference(
                key: StackListRowPrefsPreferenceKey.self,
                value: stackListRowID.map { [$0: StackListRowPrefs(
                    isEmpty: nil,
                    height: nil,
                    isExpanded: nil,
                    separatorOverride: .hidden
                )] } ?? [:]
            )
        case .toggleable(let isExpanded):
            DisclosureGroup(isExpanded: isExpanded) {
                content()
            } label: {
                wrappedHeader()
                    .modifier(SectionHeaderModifier())
            }
            .preference(
                key: StackListRowPrefsPreferenceKey.self,
                value: stackListRowID.map { [$0: StackListRowPrefs(
                    isEmpty: nil,
                    height: nil,
                    isExpanded: isExpanded.wrappedValue,
                    separatorOverride: isExpanded.wrappedValue ? .hidden : .automatic
                )] } ?? [:]
            )
            .modifier {
                if #available(iOS 16, macOS 13, *) {
                    $0.disclosureGroupStyle(StackSectionDisclosureGroupStyle(
                        trailingHeader: trailingHeader
                    ))
                } else { $0 }
            }
        }
    }
}

public extension StackSection where NavigationValue == Never {
    init(
        isExpanded: Binding<Bool>,
        trailingHeader: @escaping () -> some View = { EmptyView() },
        @ViewBuilder header: @escaping () -> Header,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(
            navigationValue: nil,
            isExpanded: isExpanded,
            trailingHeader: trailingHeader,
            header: header,
            content: content
        )
    }

    init(
        _ titleKey: LocalizedStringKey,
        isExpanded: Binding<Bool>,
        trailingHeader: @escaping () -> some View = { EmptyView() },
        @ViewBuilder content: @escaping () -> Content
    ) where Header == Text {
        self.init(
            navigationValue: nil,
            isExpanded: isExpanded,
            trailingHeader: trailingHeader,
            header: { Text(titleKey) },
            content: content
        )
    }

    init(
        @ViewBuilder header: @escaping () -> Header,
        trailingHeader: @escaping () -> some View = { EmptyView() },
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(
            navigationValue: nil,
            header: header,
            trailingHeader: trailingHeader,
            content: content
        )
    }

    init(
        _ titleKey: LocalizedStringKey,
        trailingHeader: @escaping () -> some View = { EmptyView() },
        @ViewBuilder content: @escaping () -> Content
    ) where Header == Text {
        self.init(
            navigationValue: nil,
            header: { Text(titleKey) },
            trailingHeader: trailingHeader,
            content: content
        )
    }
}

public enum StackSectionTrailingHeaderStyle: Sendable {
    case automatic
    case iconOnly
}

private struct StackSectionTrailingHeaderStyleKey: EnvironmentKey {
    static let defaultValue: StackSectionTrailingHeaderStyle = .automatic
}

public extension EnvironmentValues {
    var stackSectionTrailingHeaderStyle: StackSectionTrailingHeaderStyle {
        get { self[StackSectionTrailingHeaderStyleKey.self] }
        set { self[StackSectionTrailingHeaderStyleKey.self] = newValue }
    }
}

public extension View {
    func stackSectionTrailingHeaderStyle(_ style: StackSectionTrailingHeaderStyle) -> some View {
        environment(\.stackSectionTrailingHeaderStyle, style)
    }
}

fileprivate struct SectionHeaderModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.title2.weight(.bold))
            .foregroundStyle(.primary)
    }
}

fileprivate struct StackSectionTrailingHeaderModifier: ViewModifier {
    @Environment(\.stackSectionTrailingHeaderStyle) private var trailingHeaderStyle

    func body(content: Content) -> some View {
        content
            .font(.footnote)
            .modifier(StackSectionHeaderButtonStyleModifier(style: .trailing(trailingHeaderStyle)))
            .modifier(StackSectionTrailingHeaderFontWeightModifier())
    }
}

fileprivate enum StackSectionHeaderButtonStyle {
    case trailing(StackSectionTrailingHeaderStyle)
    case chevron
}

fileprivate struct StackSectionHeaderButtonStyleModifier: ViewModifier {
    let style: StackSectionHeaderButtonStyle

    func body(content: Content) -> some View {
#if os(iOS)
        if #available(iOS 17, *) {
            switch style {
            case .chevron:
                content
                    .frame(
                        width: StackSectionMetrics.trailingIconButtonSize,
                        height: StackSectionMetrics.trailingIconButtonSize
                    )
                    .buttonStyle(BorderedButtonStyle())
                    .controlSize(.small)
                    .buttonBorderShape(.circle)
            case .trailing(let trailingStyle):
                if trailingStyle == .iconOnly {
                    content
                        .frame(
                            width: StackSectionMetrics.trailingIconButtonSize,
                            height: StackSectionMetrics.trailingIconButtonSize
                        )
                        .buttonStyle(BorderedButtonStyle())
                        .controlSize(.small)
                        .buttonBorderShape(.circle)
                } else {
                    content
                        .buttonStyle(BorderedButtonStyle())
                        .controlSize(.small)
                        .buttonBorderShape(.capsule)
                }
            }
        } else if #available(iOS 15, *) {
            switch style {
            case .chevron:
                content
                    .buttonStyle(BorderedButtonStyle())
                    .controlSize(.small)
            case .trailing(let trailingStyle):
                if trailingStyle == .iconOnly {
                    content
                        .buttonStyle(BorderedButtonStyle())
                        .controlSize(.small)
                } else {
                    content
                        .buttonStyle(BorderedButtonStyle())
                        .controlSize(.small)
                        .buttonBorderShape(.capsule)
                }
            }
        } else {
            content
        }
#else
        content
#endif
    }
}

fileprivate struct StackSectionTrailingHeaderFontWeightModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16, macOS 13, *) {
            content.fontWeight(Font.Weight.semibold)
        } else {
            content
        }
    }
}

@available(iOS 16, macOS 13, *)
fileprivate struct StackSectionDisclosureGroupStyle: DisclosureGroupStyle {
    @ViewBuilder let trailingHeader: () -> AnyView
    @Environment(\.stackListConfig) private var config
    @Environment(\.stackSectionTrailingHeaderStyle) private var trailingHeaderStyle
    
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: trailingHeaderStyle == .iconOnly
                ? StackSectionMetrics.trailingIconHeaderRowSpacing
                : StackSectionMetrics.headerRowSpacing
            ) {
                // Title + optional inline chevron placed immediately after the title
                HStack(spacing: 5) {
                    configuration.label
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                if configuration.isExpanded {
                    trailingHeader()
                        .modifier(StackSectionTrailingHeaderModifier())
                }
                
                // Trailing circular toggle button (only control that changes expansion)
                Button {
                    configuration.isExpanded.toggle()
                } label: {
                    Image(systemName: "chevron.right")
                        .modifier {
                            if #available(iOS 16, macOS 13, *) {
                                $0.font(.footnote.weight(Font.Weight.semibold))
                            } else { $0 }
                        }
                        .rotationEffect(configuration.isExpanded ? Angle.degrees(90) : Angle.zero)
                }
                .modifier(StackSectionHeaderButtonStyleModifier(style: .chevron))
            }
            
            VStack(spacing: 0) {
                if configuration.isExpanded {
                    configuration.content
                        .padding(.top, StackSectionMetrics.contentTopSpacing)
                        .padding(.bottom, config.expandedBottomPadding)
                        .transition(.move(edge: .top).combined(with: .opacity))
                } else {
                    // Keep layout stable without mounting heavy UIKitRepresentables
                    EmptyView()
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .mask {
                Rectangle()
                    .padding(.horizontal, -StackSectionMetrics.contentMaskHorizontalOverflow)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: configuration.isExpanded)
    }
}

#if DEBUG
@available(iOS 16, macOS 14, *)
struct StackSection_Previews: PreviewProvider {
    struct Showcase: View {
        @State private var expandedYears = true
        @State private var expandedDays = false
        @State private var expandedAlbums = true
        
        var body: some View {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // 1) Toggleable, Text title, with navigation + trailing header
                        StackSection(
                            "Years",
                            navigationValue: "years",
                            isExpanded: $expandedYears,
                            trailingHeader: {
                                Button("See All") {}
                                    .buttonStyle(.bordered)
                            }) {
                                Text("2025")
                                Text("2024")
                                Text("2023")
                            }
                        
                        Divider()
                        
                        // 2) Toggleable, Text title, no navigation (no inline chevron), no trailing header
                        StackSection("Days",
                                     isExpanded: $expandedDays) {
                            Text("Monday")
                            Text("Tuesday")
                            Text("Wednesday")
                        }
                        
                        Divider()
                        
                        // 3) Toggleable, custom header view, with navigation + trailing header control
                        StackSection(
                            navigationValue: "albums",
                            isExpanded: $expandedAlbums,
                            trailingHeader: {
                                Toggle(isOn: .constant(true)) { Text("") }
                                    .labelsHidden()
                            },
                            header: {
                                HStack(spacing: 8) {
                                    Image(systemName: "photo.on.rectangle")
                                    Text("Albums")
                                }
                            },
                            content: {
                                Text("Favorites")
                                Text("Recents")
                                Text("Shared")
                            })
                        
                        Divider()
                        
                        // 4) Always expanded, Text title, with navigation + trailing header
                        StackSection("Places",
                                     navigationValue: "places",
                                     trailingHeader: {
                            Button("See All") {}
                                .buttonStyle(.borderedProminent)
                        }) {
                            Text("Japan")
                            Text("Canada")
                            Text("Italy")
                        }
                        
                        Divider()
                        
                        // 5) Always expanded, custom header, trailing menu
                        StackSection(
                            header: {
                                HStack(spacing: 8) {
                                    Image(systemName: "memories")
                                    Text("Memories")
                                }
                            },
                            trailingHeader: {
                                Menu {
                                    Button("Sort by Name") {}
                                    Button("Sort by Date") {}
                                } label: {
                                    Image(systemName: "ellipsis.circle")
                                }
                            },
                            content: {
                                Text("Best of 2024")
                                Text("Trips")
                            })
                    }
                    .padding()
                }
                .navigationDestination(for: String.self) { value in
                    Text("Navigated to: \(value)")
                        .navigationTitle(value.capitalized)
                }
                .navigationTitle("StackSection Showcase")
            }
        }
    }
    
    static var previews: some View {
        Group {
            Showcase()
                .previewDisplayName("StackSection Showcase")
        }
#if os(iOS)
        .background(Color(UIColor.systemBackground))
#endif
    }
}
#endif
