import SwiftUI

public struct StackListGroupBoxStyle: GroupBoxStyle {
    @Environment(\.stackListStyle) private var stackListStyle
    
    public func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading) {
            configuration.label
                .modifier {
                    if #available(iOS 16, macOS 13, *) {
                        $0.backgroundStyle(stackListStyle == .grouped ? Color.secondarySystemGroupedBackground : Color.secondarySystemBackground)
                    } else { $0 }
                }
                .buttonStyle(.bordered)
            
            configuration.content
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(stackListStyle == .grouped ? Color.secondarySystemGroupedBackground : Color.secondarySystemBackground)
        }
    }
}

public extension GroupBoxStyle where Self == StackListGroupBoxStyle {
    static var stackList: Self { Self() }
}
