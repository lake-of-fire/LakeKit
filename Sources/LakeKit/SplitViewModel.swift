import SwiftUI
import SplitView

public class SplitViewModel: NSObject, ObservableObject {
    public var userDefaultsPrefix: String? {
        didSet {
            refresh()
        }
    }
    public var assistantSide: SplitSide = .secondary {
        didSet {
            refresh()
        }
    }
    @Published public var assistantFraction: FractionHolder
    @Published public var assistantLayout: LayoutHolder = .init(.horizontal)
    @Published public var assistantHide: SideHolder
    
//    private var defaultAssistantFraction = 0.5
    private var hasSizedLayout = false
    
    public init(userDefaultsPrefix: String? = "main", assistantSide: SplitSide = .secondary, assistantFraction: CGFloat = 0.5) {
        assistantHide = SideHolder(assistantSide)
        self.assistantSide = assistantSide
//        defaultAssistantFraction = assistantFraction
        self.assistantFraction = assistantSide == .primary ? .init(assistantFraction) : .init(1 - assistantFraction)
        
        if let userDefaultsPrefix = userDefaultsPrefix {
            self.userDefaultsPrefix = userDefaultsPrefix
        }
        
        super.init()
    }
    
    internal func refresh() {
        if let userDefaultsPrefix = userDefaultsPrefix {
            assistantFraction = FractionHolder.usingUserDefaults(assistantFraction.value, key: "\(userDefaultsPrefix)-SplitViewModel-assistantFraction")
            assistantLayout = LayoutHolder.usingUserDefaults(assistantLayout.value, key: "\(userDefaultsPrefix)-SplitViewModel-assistantLayout")
            assistantHide = SideHolder.usingUserDefaults(assistantSide, key: "\(userDefaultsPrefix)-SplitViewModel-assistantHide")
        } else {
            assistantFraction = .init(assistantFraction.value)
            assistantLayout = .init(assistantLayout.value)
            assistantHide = SideHolder(assistantSide)
        }
    }
    
    @MainActor
    public func refreshLayout(geometrySize: CGSize) {
        //        if assistantHide.side != .none {
        //            return
        //        }
        if hasSizedLayout {
            withAnimation {
                refreshLayoutWithoutAnimation(geometrySize: geometrySize)
            }
        } else {
            refreshLayoutWithoutAnimation(geometrySize: geometrySize)
            hasSizedLayout = true
        }
    }
    
    private func refreshLayoutWithoutAnimation(geometrySize: CGSize) {
        //        if assistantHide.side != .none {
        //            return
        //        }
        if geometrySize.width >= geometrySize.height {
            assistantLayout.value = .horizontal
        } else {
            assistantLayout.value = .vertical
        }
    }
}
