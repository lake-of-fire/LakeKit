import Foundation
#if os(iOS)
import UIKit
import UniformTypeIdentifiers
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
    
    public static func copy(_ attributedString: NSAttributedString, fallbackPlainText: String? = nil) {
#if os(iOS)
        let pasteboard = UIPasteboard.general
        var item: [String: Any] = [:]
        let plainText = fallbackPlainText ?? attributedString.string
        item[UTType.plainText.identifier] = plainText
        if let data = try? attributedString.data(from: NSRange(location: 0, length: attributedString.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.rtfd]) {
            item[UTType.rtfd.identifier] = data
        } else if let data = try? attributedString.data(from: NSRange(location: 0, length: attributedString.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]) {
            item[UTType.rtf.identifier] = data
        }
        pasteboard.setItems([item], options: [:])
#elseif os(macOS)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        var writers: [NSPasteboardWriting] = [attributedString]
        if let plainText = fallbackPlainText {
            writers.append(plainText as NSString)
        }
        pasteboard.writeObjects(writers)
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
