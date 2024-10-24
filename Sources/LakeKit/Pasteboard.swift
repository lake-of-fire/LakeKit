import Foundation
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

public struct Pasteboard {
    public static func copy(_ text: String) {
#if os(iOS)
        UIPasteboard.general.string = text
#elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
#endif
    }
    
    public static func copy(_ url: URL) {
#if os(iOS)
        UIPasteboard.general.url = url
#elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([url as NSPasteboardWriting])

#endif
    }
}
