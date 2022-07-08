import Foundation
import SwiftUI

public struct SettingsView<Content>: View where Content: View {
    let tabItems: Content
    
    public var body: some View {
        TabView {
            tabItems
        }
        .frame(minWidth: 450, minHeight: 250)
    }
    
    public init(@ViewBuilder tabItems: () -> Content) {
        self.tabItems = tabItems()
    }
        
}
 
