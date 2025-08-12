import SwiftUI

public struct StackSection<Header: View, Content: View>: View {
    private enum Expansion { case toggleable(Binding<Bool>), alwaysExpanded }
    private let expansion: Expansion
    @ViewBuilder private let header: () -> Header
    @ViewBuilder private let content: () -> Content
    
    public init(
        isExpanded: Binding<Bool>,
        @ViewBuilder header: @escaping () -> Header,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.expansion = .toggleable(isExpanded)
        self.header = header
        self.content = content
    }
    
    public init(
        _ titleKey: LocalizedStringKey,
        isExpanded: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) where Header == Text {
        self.init(isExpanded: isExpanded, header: { Text(titleKey) }, content: content)
    }
    
    public init<S: StringProtocol>(
        _ title: S,
        isExpanded: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) where Header == Text {
        self.init(isExpanded: isExpanded, header: { Text(title) }, content: content)
    }
    
    public init(
        @ViewBuilder header: @escaping () -> Header,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.expansion = .alwaysExpanded
        self.header = header
        self.content = content
    }
    
    public init(
        _ titleKey: LocalizedStringKey,
        @ViewBuilder content: @escaping () -> Content
    ) where Header == Text {
        self.init(header: { Text(titleKey) }, content: content)
    }
    
    public init<S: StringProtocol>(
        _ title: S,
        @ViewBuilder content: @escaping () -> Content
    ) where Header == Text {
        self.init(header: { Text(title) }, content: content)
    }
    
    @ViewBuilder
    public var body: some View {
        switch expansion {
        case .alwaysExpanded:
            VStack(alignment: .leading, spacing: 0) {
                header().modifier(AppleMusicSectionHeaderModifier())
                content()
            }
            
        case .toggleable(let isExpanded):
            DisclosureGroup(isExpanded: isExpanded) {
                content()
            } label: {
                header()
            }
            .modifier {
                if #available(iOS 16, macOS 13, *) {
                    $0.disclosureGroupStyle(SecondaryChevronDisclosureGroupStyle())
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

@available(iOS 16, macOS 13, *)
fileprivate struct SecondaryChevronDisclosureGroupStyle: DisclosureGroupStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            withAnimation {
                configuration.isExpanded.toggle()
            }
        } label: {
            HStack(spacing: 8) {
                configuration.label
                    .modifier(AppleMusicSectionHeaderModifier())
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.title3.weight(.semibold))
                    .rotationEffect(configuration.isExpanded ? .degrees(90) : .zero)
                    .animation(.easeInOut(duration: 0.2), value: configuration.isExpanded)
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

fileprivate struct AppleMusicSectionHeaderModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.title3.weight(.semibold))
//            .kerning(0.2)
//            .textCase(nil)
            .foregroundStyle(.primary)
    }
}
