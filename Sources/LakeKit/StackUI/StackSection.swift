import SwiftUI
import NavigationBackport

fileprivate enum StackSectionMetrics {
    static let headerRowSpacing: CGFloat = 8
    static let contentTopSpacing: CGFloat = 8
}

public struct StackSection<Header: View, Content: View>: View {
    private enum Expansion { case toggleable(Binding<Bool>), alwaysExpanded }
    private let expansion: Expansion
    private let navigationValue: AnyHashable?
    @ViewBuilder private let navigationDestination: (() -> AnyView)?
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
        navigationValue: AnyHashable? = nil,
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
        self.navigationDestination = nil
    }
    
    public init(
        _ titleKey: LocalizedStringKey,
        navigationValue: AnyHashable? = nil,
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
        navigationValue: AnyHashable? = nil,
        @ViewBuilder header: @escaping () -> Header,
        trailingHeader: @escaping () -> some View = { EmptyView() },
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.expansion = .alwaysExpanded
        self.navigationValue = navigationValue
        self.header = header
        self.trailingHeader = { AnyView(trailingHeader()) }
        self.content = content
        self.navigationDestination = nil
    }
    
    public init(
        _ titleKey: LocalizedStringKey,
        navigationValue: AnyHashable? = nil,
        trailingHeader: @escaping () -> some View = { EmptyView() },
        @ViewBuilder content: @escaping () -> Content
    ) where Header == Text {
        self.init(
            navigationValue: navigationValue,
            header: { Text(titleKey) },
            trailingHeader: trailingHeader,
            content: content)
    }
    
    // MARK: - Destination-based initializers
    
    /// Toggleable, custom header
    public init(
        isExpanded: Binding<Bool>,
        trailingHeader: @escaping () -> some View = { EmptyView() },
        @ViewBuilder header: @escaping () -> Header,
        @ViewBuilder content: @escaping () -> Content,
        navigationDestination: @escaping () -> some View
    ) {
        self.expansion = .toggleable(isExpanded)
        self.navigationValue = nil
        self.header = header
        self.content = content
        self.trailingHeader = { AnyView(trailingHeader()) }
        self.navigationDestination = { AnyView(navigationDestination()) }
    }
    
    /// Toggleable, LocalizedStringKey title (Header == Text)
    public init(
        _ titleKey: LocalizedStringKey,
        isExpanded: Binding<Bool>,
        trailingHeader: @escaping () -> some View = { EmptyView() },
        @ViewBuilder content: @escaping () -> Content,
        navigationDestination: @escaping () -> some View
    ) where Header == Text {
        self.init(
            isExpanded: isExpanded,
            trailingHeader: trailingHeader,
            header: { Text(titleKey) },
            content: content,
            navigationDestination: navigationDestination,
        )
    }
    
    
    /// Always-expanded, custom header
    public init(
        @ViewBuilder header: @escaping () -> Header,
        trailingHeader: @escaping () -> some View = { EmptyView() },
        @ViewBuilder content: @escaping () -> Content,
        navigationDestination: @escaping () -> some View
    ) {
        self.expansion = .alwaysExpanded
        self.navigationValue = nil
        self.header = header
        self.trailingHeader = { AnyView(trailingHeader()) }
        self.content = content
        self.navigationDestination = { AnyView(navigationDestination()) }
    }
    
    /// Always-expanded, LocalizedStringKey title (Header == Text)
    public init(
        _ titleKey: LocalizedStringKey,
        trailingHeader: @escaping () -> some View = { EmptyView() },
        @ViewBuilder content: @escaping () -> Content,
        navigationDestination: @escaping () -> some View
    ) where Header == Text {
        self.init(
            header: { Text(titleKey) },
            trailingHeader: trailingHeader,
            content: content,
            navigationDestination: navigationDestination
        )
    }
    
    
    @ViewBuilder
    private func wrappedHeader() -> some View {
        if let navigationDestination {
            if #available(iOS 16, macOS 13, *) {
                NavigationLink(destination: { navigationDestination() }) {
                    headerWithChevron()
                }
            } else {
                header()
            }
        } else if let navigationValue {
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
            if (navigationValue != nil || navigationDestination != nil),
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
                key: StackListRowSeparatorOverridePreferenceKey.self,
                value: stackListRowID.map { [$0: .hidden] } ?? [:]
            )
        case .toggleable(let isExpanded):
            DisclosureGroup(isExpanded: isExpanded) {
                content()
            } label: {
                wrappedHeader()
                    .modifier(SectionHeaderModifier())
            }
            .preference(
                key: StackListRowSeparatorOverridePreferenceKey.self,
                value: stackListRowID.map { [$0: (isExpanded.wrappedValue ? .hidden : .automatic)] } ?? [:]
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

fileprivate struct SectionHeaderModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.title2.weight(.bold))
            .foregroundStyle(.primary)
    }
}

fileprivate struct StackSectionTrailingHeaderModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
#if os(iOS)
            .buttonStyle(.bordered)
#endif
            .controlSize(.small)
            .font(.footnote)
            .modifier {
                if #available(iOS 16, macOS 13, *) {
                    $0.fontWeight(.bold)
                } else { $0 }
            }
    }
}

@available(iOS 16, macOS 13, *)
fileprivate struct StackSectionDisclosureGroupStyle: DisclosureGroupStyle {
    @ViewBuilder let trailingHeader: () -> AnyView
    
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: StackSectionMetrics.headerRowSpacing) {
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
                    withAnimation(.easeInOut(duration: 0.25)) {
                        configuration.isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .imageScale(.small)
                        .rotationEffect(configuration.isExpanded ? .degrees(90) : .zero)
#if os(iOS)
                        .modifier {
                            if #available(iOS 16, macOS 13, *) {
                                $0.fontWeight(.semibold)
                            } else { $0 }
                        }
#endif
                }
#if os(iOS)
                .buttonStyle(.bordered)
#endif
                //                .controlSize(.mini)
                .modifier {
                    if #available(iOS 17, macOS 14, *) {
                        $0
                            .buttonBorderShape(.circle)
                            .backgroundStyle(Color.stackListGroupedBackground)
                    } else {
                        $0
                    }
                }
            }
            
            VStack(spacing: 0) {
                configuration.content
                    .padding(.top, StackSectionMetrics.contentTopSpacing)
                    .opacity(configuration.isExpanded ? 1 : 0)
                    .frame(height: configuration.isExpanded ? nil : 0, alignment: .top)
                    .clipped()
                    .allowsHitTesting(configuration.isExpanded)
                    .accessibilityHidden(!configuration.isExpanded)
            }
        }
        .clipped()
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
                            navigationValue: nil,
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
