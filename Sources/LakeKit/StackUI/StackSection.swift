fileprivate enum StackSectionMetrics {
    static let headerRowSpacing: CGFloat = 10
    static let contentTopSpacing: CGFloat = 8
}
import SwiftUI
import NavigationBackport

public struct StackSection<Header: View, Content: View>: View {
    private enum Expansion { case toggleable(Binding<Bool>), alwaysExpanded }
    private let expansion: Expansion
    private let navigationValue: AnyHashable?
    @ViewBuilder private let header: () -> Header
    @ViewBuilder private let content: () -> Content
    @ViewBuilder private let trailingHeader: () -> AnyView
    
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
    
    public init<S: StringProtocol>(
        _ title: S,
        navigationValue: AnyHashable? = nil,
        isExpanded: Binding<Bool>,
        trailingHeader: @escaping () -> some View = { EmptyView() },
        @ViewBuilder content: @escaping () -> Content
    ) where Header == Text {
        self.init(
            navigationValue: navigationValue,
            isExpanded: isExpanded,
            trailingHeader: trailingHeader,
            header: { Text(title) },
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
    
    public init<S: StringProtocol>(
        _ title: S,
        navigationValue: AnyHashable? = nil,
        trailingHeader: @escaping () -> some View = { EmptyView() },
        @ViewBuilder content: @escaping () -> Content
    ) where Header == Text {
        self.init(
            navigationValue: navigationValue,
            header: { Text(title) },
            trailingHeader: trailingHeader,
            content: content)
    }
    
    @ViewBuilder
    private func wrappedHeader() -> some View {
        if let navigationValue {
            if #available(iOS 16, macOS 13, *) {
                NavigationLink(value: navigationValue) {
                    header()
                    headerChevron()
                }
            } else {
                NBNavigationLink(value: navigationValue) {
                    header()
                    headerChevron()
                }
            }
        } else {
            header()
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
                        .controlSize(.small)
                }
                content()
            }
        case .toggleable(let isExpanded):
            DisclosureGroup(isExpanded: isExpanded) {
                content()
                    .transition(
                        .asymmetric(
                            insertion: .scale(scale: 1, anchor: .top).combined(with: .opacity),
                            removal: .scale(scale: 1, anchor: .top).combined(with: .opacity)
                        )
                    )
                    .clipped()
            } label: {
                wrappedHeader()
                    .modifier(SectionHeaderModifier())
            }
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

fileprivate struct StackSectionTitleView: View {
    let title: String
    
    @ScaledMetric(relativeTo: .headline) private var sectionTitleVerticalPadding: CGFloat = 7
    
    var body: some View {
        Text(title)
            .font(.headline)
            .padding(.vertical, sectionTitleVerticalPadding)
            .padding(.trailing, 4)
    }
}

fileprivate struct SectionHeaderModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.title2.weight(.bold))
            .foregroundStyle(.primary)
    }
}

@available(iOS 16, macOS 13, *)
fileprivate struct StackSectionDisclosureGroupStyle: DisclosureGroupStyle {
    let trailingHeader: () -> AnyView
    
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: StackSectionMetrics.contentTopSpacing) {
            HStack(spacing: StackSectionMetrics.headerRowSpacing) {
                // Title + optional inline chevron placed immediately after the title
                HStack(spacing: 5) {
                    configuration.label
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Trailing header controls
                trailingHeader()
                    .controlSize(.small)
                
                // Trailing circular toggle button (only control that changes expansion)
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { configuration.isExpanded.toggle() }
                } label: {
                    Image(systemName: "chevron.right")
                        .rotationEffect(configuration.isExpanded ? .degrees(90) : .zero)
                        .animation(.easeInOut(duration: 0.2), value: configuration.isExpanded)
                }
#if os(iOS)
                .buttonStyle(.bordered)
#endif
                .controlSize(.small)
                .modifier {
                    if #available(iOS 17, macOS 14, *) {
                        $0.buttonBorderShape(.circle)
                    } else {
                        $0
                    }
                }
            }
            
            if configuration.isExpanded {
                configuration.content
                    .transition(
                        .asymmetric(
                            insertion: .scale(scale: 1, anchor: .top).combined(with: .opacity),
                            removal: .scale(scale: 1, anchor: .top).combined(with: .opacity)
                        )
                    )
                    .clipped()
            }
        }
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
        .background(Color(UIColor.systemBackground))
    }
}
#endif
