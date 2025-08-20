import SwiftUI

public struct StackListGroupBoxStyle: GroupBoxStyle {
    public func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading) {
            configuration.label
                .modifier {
                    if #available(iOS 16, macOS 13, *) {
                        $0.backgroundStyle(Color.stackListGroupedBackground)
                    } else { $0 }
                }
                .buttonStyle(.bordered)
            
            configuration.content
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.stackListGroupedBackground)
        }
    }
}

public extension GroupBoxStyle where Self == StackListGroupBoxStyle {
    static var stackList: Self { Self() }
}
