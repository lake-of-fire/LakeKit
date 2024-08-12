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
    @Published internal var assistantHide: SideHolder = .init()
    private var hasSizedLayout = false
    
    public init(userDefaultsPrefix: String? = "main", assistantSide: SplitSide = .secondary, assistantFraction: CGFloat = 0.5) {
        self.assistantSide = assistantSide
        self.assistantFraction = assistantSide == .primary ? .init(assistantFraction) : .init(1 - assistantFraction)
        
        if let userDefaultsPrefix = userDefaultsPrefix {
            self.userDefaultsPrefix = userDefaultsPrefix
        }
        
        super.init()
        
        self.refresh()
    }
    
    internal func refreshAssistantFraction() {
        if let userDefaultsPrefix = userDefaultsPrefix {
            assistantFraction = FractionHolder.usingUserDefaults(assistantFraction.value, key: "\(userDefaultsPrefix)-\(assistantLayout.isHorizontal)-SplitViewModel-assistantFraction")
        } else {
            assistantFraction = .init(assistantFraction.value)
        }
    }
    
    internal func refresh() {
        refreshAssistantFraction()
        if let userDefaultsPrefix = userDefaultsPrefix {
            assistantLayout = LayoutHolder.usingUserDefaults(assistantLayout.value, key: "\(userDefaultsPrefix)-SplitViewModel-assistantLayout")
            assistantHide = SideHolder.usingUserDefaults(assistantSide, key: "\(userDefaultsPrefix)-SplitViewModel-assistantHide")
        } else {
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
        if geometrySize.width >= geometrySize.height * 1.2 {
            if assistantLayout.value != .horizontal {
                assistantLayout.value = .horizontal
                debugPrint("!! UPDATE TO HORIZONTAL")
                refreshAssistantFraction()
            }
        } else if assistantLayout.value != .vertical {
            assistantLayout.value = .vertical
            debugPrint("!! UPDATE TO VERTICAL")
            refreshAssistantFraction()
        }
    }
}
