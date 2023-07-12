import Foundation
import SplitView

public class SplitViewModel: NSObject, ObservableObject {
    @Published public var assistantLayout = LayoutHolder()
    @Published public var assistantHide = SideHolder()

    public override init() {
        super.init()
    }
}
