import SwiftUI

public struct DismissalButtonLabel: View {
    var imageSystemName = "xmark"
    
    @Environment(\.colorScheme) var colorScheme
    
    public var body: some View {
        ZStack {
            Circle()
                .fill(Color(white: colorScheme == .dark ? 0.19 : 0.93))
            Image(systemName: imageSystemName)
                .resizable()
                .scaledToFit()
                .font(Font.body.weight(.bold))
                .scaleEffect(0.416)
                .foregroundColor(Color(white: colorScheme == .dark ? 0.62 : 0.51))
        }
        .frame(width: 30, height: 30)
        .padding(1)
    }
    
    public init(imageSystemName: String? = nil) {
        if let imageSystemName = imageSystemName {
            self.imageSystemName = imageSystemName
        }
    }
}
