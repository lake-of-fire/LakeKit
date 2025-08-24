import SwiftUI

/// A reusable empty-state view that matches the platform look & feel.
/// - Uses a GroupBox with the system image as the label.
/// - Places title + supporting text on the leading side.
/// - Accepts an optional trailing control (e.g., a “Create” button).
public struct EmptyStateBoxView<Trailing: View>: View {
    public let title: Text
    public let text: Text
    public let systemImageName: String
    @ViewBuilder public var trailingView: Trailing
    
    // Keep roughly in line with card/list cell heights so sections don't collapse too small.
    @ScaledMetric(relativeTo: .footnote) private var minHeight: CGFloat = 160
    
    public init(
        title: Text,
        text: Text,
        systemImageName: String,
        @ViewBuilder trailingView: () -> Trailing
    ) {
        self.title = title
        self.text = text
        self.systemImageName = systemImageName
        self.trailingView = trailingView()
    }
    
    public var body: some View {
        GroupBox {
            HStack(alignment: .top, spacing: 12) {
                VStack(spacing: 0) {
                    Spacer(minLength: 20)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        title
                            .font(.subheadline)
                            .bold()
                        text
                            .font(.footnote)
                    }
                    .environment(\._lineHeightMultiple, 0.85)
                    .imageScale(.small)
                    .foregroundStyle(.secondary)
                }
            }
            .modifier {
                if #available(iOS 16, macOS 13, *) {
                    $0.backgroundStyle(.secondary)
                } else { $0 }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Image(systemName: systemImageName)
                    .imageScale(.large)
                    .foregroundStyle(.tertiary)
                Spacer(minLength: 8)
                trailingView
                    .controlSize(.mini)
                    .modifier {
                        if #available(iOS 16, macOS 13, *) {
                            $0.fontWeight(.semibold)
                        } else { $0 }
                    }
            }
        }
        .groupBoxStyle(.stackList)
        .frame(minHeight: minHeight)
        .enableInjection()
    }
}

// Convenience initializer when no trailing view is supplied.
public extension EmptyStateBoxView where Trailing == EmptyView {
    init(title: Text, text: Text, systemImageName: String) {
        self.init(title: title, text: text, systemImageName: systemImageName) { EmptyView() }
    }
}
