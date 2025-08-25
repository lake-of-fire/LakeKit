import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

extension Color {
    public static var groupedListBackground: Color {
#if canImport(UIKit)
        return Color(uiColor: UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .light:
                return UIColor(red: 242 / 255, green: 242 / 255, blue: 247 / 255, alpha: 1)
            case .dark:
                return UIColor.black
            default:
                return UIColor(red: 242 / 255, green: 242 / 255, blue: 247 / 255, alpha: 1)
            }
        })
#else
        return UIColor(red: 242 / 255, green: 242 / 255, blue: 247 / 255, alpha: 1)
#endif
    }
}
