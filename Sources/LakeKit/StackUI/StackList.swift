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
    }
}
