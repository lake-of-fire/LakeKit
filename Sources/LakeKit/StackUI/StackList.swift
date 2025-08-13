import SwiftUI

public struct StackList<Content: View>: View {
    @ViewBuilder private let content: () -> Content
    
    public init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .modifier {
            if #available(iOS 17, macOS 14, *) {
                $0.contentMargins(15, for: .scrollContent)
                $0.contentMargins(0, for: .scrollIndicators)
            } else {
                $0.padding()
            }
        }
    }
}
