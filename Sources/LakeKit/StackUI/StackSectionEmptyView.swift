import SwiftUI

// Generic empty-state configuration + view usable across sections/lists
public struct StackSectionEmptyStateConfiguration: Equatable, Sendable {
    public let title: String
    public let text: String
    public let systemImageName: String
    
    public init(title: String, text: String, systemImageName: String) {
        self.title = title
        self.text = text
        self.systemImageName = systemImageName
    }
}

/// A reusable empty-state view that matches the platform look & feel.
/// - Uses a GroupBox with the system image as the label.
/// - Places title + supporting text on the leading side.
/// - Accepts an optional trailing control (e.g., a “Create” button).
public struct StackSectionEmptyStateView<Trailing: View>: View {
    public let config: StackSectionEmptyStateConfiguration
    @ViewBuilder public var trailingView: Trailing
    
    // Keep roughly in line with card/list cell heights so sections don't collapse too small.
    @ScaledMetric(relativeTo: .footnote) private var verticalPadding: CGFloat = 40
    
    public init(
        config: StackSectionEmptyStateConfiguration,
        @ViewBuilder trailingView: () -> Trailing
    ) {
        self.config = config
        self.trailingView = trailingView()
    }
    
    public var body: some View {
        GroupBox {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(config.title)
                        .font(.subheadline)
                        .bold()
                    Text(config.text)
                        .font(.body)
                }
                .padding(.top, verticalPadding)
                Spacer(minLength: 8)
                trailingView
            }
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Image(systemName: config.systemImageName)
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .enableInjection()
    }
}

// Convenience initializer when no trailing view is supplied.
public extension StackSectionEmptyStateView where Trailing == EmptyView {
    init(config: StackSectionEmptyStateConfiguration) {
        self.init(config: config) { EmptyView() }
    }
}
