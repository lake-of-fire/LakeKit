import SwiftUI
#if canImport(AppKit)
import AppKit

extension NSFont.TextStyle {
    internal init(
        fromSwiftUIFontTextStyle textStyle: Font.TextStyle
    ) {
        switch textStyle {
        case .largeTitle:
            self = .largeTitle
        case .title:
            self = .title1
        case .title2:
            self = .title2
        case .title3:
            self = .title3
        case .headline:
            self = .headline
        case .subheadline:
            self = .subheadline
        case .body:
            self = .body
        case .callout:
            self = .callout
        case .footnote:
            self = .footnote
        case .caption:
            self = .caption1
        case .caption2:
            self = .caption2
        @unknown default:
            self = .body
        }
    }
}

public extension Font {
    static func pointSize(for textStyle: Font.TextStyle) -> CGFloat {
        NSFont.preferredFont(
            forTextStyle: NSFont.TextStyle(fromSwiftUIFontTextStyle: textStyle)
        )
        .pointSize
    }
}

#elseif canImport(UIKit)
import UIKit

extension UIFont.TextStyle {
    
    init(
        fromSwiftUIFontTextStyle textStyle: Font.TextStyle
    ) {
        switch textStyle {
        case .largeTitle:
            self = .largeTitle
        case .title:
            self = .title1
        case .title2:
            self = .title2
        case .title3:
            self = .title3
        case .headline:
            self = .headline
        case .subheadline:
            self = .subheadline
        case .body:
            self = .body
        case .callout:
            self = .callout
        case .footnote:
            self = .footnote
        case .caption:
            self = .caption1
        case .caption2:
            self = .caption2
        @unknown default:
            self = .body
        }
    }
}

extension Font {
    public static func pointSize(for textStyle: Font.TextStyle) -> CGFloat {
        UIFont.preferredFont(
            forTextStyle: UIFont.TextStyle(fromSwiftUIFontTextStyle: textStyle)
        )
        .pointSize
    }
}

#endif
