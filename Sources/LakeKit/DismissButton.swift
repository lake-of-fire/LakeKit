import SwiftUI

public struct DismissButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme
    
    public init() {
    }
    
    public func makeBody(configuration: Configuration) -> some View {
        let isPressed = configuration.isPressed
        
        return configuration.label
            .labelsHidden()
            .padding()
            .background(
                Circle()
                    .fill(Color(white: colorScheme == .dark ? 0.19 : 0.93))
                //.brightness(isPressed ? 0.1 : 0) // Aclara el color cuando está presionado
                    .frame(width: 32, height: 32)
            )
            .overlay(
                Image(systemName: "xmark")
                    .resizable()
                    .scaledToFit()
                    .font(Font.body.weight(.bold))
                    .scaleEffect(0.416)
                    .foregroundColor(Color(white: colorScheme == .dark ? 0.62 : 0.51))
                
            )
            .buttonStyle(PlainButtonStyle())
            .opacity(isPressed ? 0.18 : 1)
    }
}
