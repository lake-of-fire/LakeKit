import SwiftUI

/// A reusable empty-state view that matches the platform look & feel.
/// - Uses a GroupBox with the system image as the label.
/// - Places title + supporting text on the leading side.
/// - Accepts an optional trailing control (e.g., a “Create” button).
public struct EmptyStateBoxView<Trailing: View>: View {
    public let title: Text
    public let text: Text
    public let systemImageName: String
    public let controlSize: ControlSize
    @ViewBuilder public var trailingView: Trailing

    @Environment(\.stackListStyle) private var stackListStyle
    @Environment(\.stackListIsGroupedContext) private var stackListGroupedContext
    
    public init(
        title: Text,
        text: Text,
        systemImageName: String,
        controlSize: ControlSize = .mini,
        @ViewBuilder trailingView: () -> Trailing
    ) {
        self.title = title
        self.text = text
        self.systemImageName = systemImageName
        self.controlSize = controlSize
        self.trailingView = trailingView()
    }
    
    public var body: some View {
        GroupBox {
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
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .modifier {
                if #available(iOS 16, macOS 13, *) {
                    $0.backgroundStyle(.secondary)
                } else { $0 }
            }
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Image(systemName: systemImageName)
                    .imageScale(.large)
                    .foregroundStyle(.tertiary)
                Spacer(minLength: 8)
                trailingView
                    .controlSize(controlSize)
                    .modifier {
                        if #available(iOS 16, macOS 13, *) {
                            $0.fontWeight(.semibold)
                        } else { $0 }
                    }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .environment(\.stackListBackgroundColorOverride, preferredBackgroundColor)
        .applyStackListGroupBoxStyle(isGrouped: isGroupedAppearance)
        .fixedSize(horizontal: false, vertical: true)
        //.enableInjection()
    }
}

// Convenience initializer when no trailing view is supplied.
public extension EmptyStateBoxView where Trailing == EmptyView {
    init(title: Text, text: Text, systemImageName: String, controlSize: ControlSize = .mini) {
        self.init(title: title, text: text, systemImageName: systemImageName, controlSize: controlSize) { EmptyView() }
    }
}

private extension EmptyStateBoxView {
    var isGroupedAppearance: Bool {
        stackListGroupedContext || stackListStyle == .grouped
    }

    var preferredBackgroundColor: Color {
        isGroupedAppearance ? Color.stackListCardBackgroundGrouped : Color.stackListCardBackgroundPlain
    }

}

private extension View {
    @ViewBuilder
    func applyStackListGroupBoxStyle(isGrouped: Bool) -> some View {
        if isGrouped {
            self.groupBoxStyle(.groupedStackList)
        } else {
            self.groupBoxStyle(.stackList)
        }
    }
}
