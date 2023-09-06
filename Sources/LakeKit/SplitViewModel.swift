import SwiftUI
import SplitView

public class SplitViewModel: NSObject, ObservableObject {
    @Published public var assistantFraction: FractionHolder
    @Published public var assistantLayout: LayoutHolder
    @Published public var assistantHide: SideHolder
    
    public init(userDefaultsPrefix: String = "main") {
        assistantFraction = FractionHolder.usingUserDefaults(0.25, key: "\(userDefaultsPrefix)-SplitViewModel-assistantFraction")
        assistantLayout = LayoutHolder.usingUserDefaults(.horizontal, key: "\(userDefaultsPrefix)-SplitViewModel-assistantLayout")
        assistantHide = SideHolder.usingUserDefaults(.primary , key: "\(userDefaultsPrefix)-SplitViewModel-assistantHide")
        
        super.init()
    }
    
    public func refreshLayout(geometrySize: CGSize) {
        if assistantHide.side != .none {
            return
        }
        Task { @MainActor in
            withAnimation {
                if geometrySize.width >= geometrySize.height {
                    assistantLayout.value = .horizontal
                } else {
                    assistantLayout.value = .vertical
                }
            }
        }
    }
}
