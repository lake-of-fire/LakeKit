import SwiftUI

public struct DoneButton: View {
    let action: () -> Void
    
    public init(action: @escaping () -> Void) {
        self.action = action
    }
    
    public var body: some View {
        Button {
            action()
        } label: {
            if #available(iOS 26, macOS 26, *) {
                Label("Done", systemImage: "checkmark")
                    .buttonStyle(.glassProminent)
                    .labelStyle(.iconOnly)
            } else {
                Text("Done")
#if os(iOS)
                    .bold()
#endif
            }
        }
    }
}
