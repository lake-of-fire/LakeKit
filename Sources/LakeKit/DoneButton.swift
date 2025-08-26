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
                    .labelStyle(.iconOnly)
            } else {
                Text("Done")
#if os(iOS)
                    .bold()
#endif
            }
        }
        .modifier {
            if #available(iOS 26, macOS 26, *) {
                $0.buttonStyle(.glassProminent)
            } else { $0 }
        }
    }
}
