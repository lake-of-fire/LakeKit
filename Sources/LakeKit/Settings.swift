import Foundation
import SwiftUI

public struct SettingsView<Content>: View where Content: View {
    let tabItems: Content
    
    public var body: some View {
        TabView {
            tabItems
        }
        .frame(idealWidth: 450, maxWidth: 550, minHeight: 250, idealHeight: 300)
    }
    
    public init(@ViewBuilder tabItems: () -> Content) {
        self.tabItems = tabItems()
    }
        
}
