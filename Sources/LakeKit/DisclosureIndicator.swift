import SwiftUI

public struct DisclosureIndicator: View {
    public init() { }
    
    public var body: some View {
        Image(systemName: "chevron.right")
//            .font(.footnote)
            .imageScale(.small)
            .modifier {
                if #available(iOS 16, macOS 13, *) {
                    $0.fontWeight(.semibold)
                } else { $0 }
            }
            .foregroundStyle(.tertiary)
    }
}
