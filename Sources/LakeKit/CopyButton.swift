import SwiftUI

public struct CopyButton: View {
    let title: String
    @Binding var textToCopy: String
    
    public var body: some View {
        Button {
            Pasteboard.copy(textToCopy)
        } label: {
            Label(title, systemImage: "doc.on.doc")
        }
    }
    
    public init(_ title: String, textToCopy: Binding<String>) {
        self.title = title
        _textToCopy = textToCopy
    }
}
