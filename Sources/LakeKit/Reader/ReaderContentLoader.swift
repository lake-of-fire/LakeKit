import Foundation
import RealmSwift
import MarkdownKit
import SwiftSoup
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Loads from any source by URL.
public struct ReaderContentLoader {
    public static func load(url: URL, persist: Bool = true, realmConfiguration: Realm.Configuration) -> (any ReaderContentModel)? {
        if url.scheme == "about" && url.absoluteString.lowercased().starts(with: "about:load") {
            // Don't persist about:load visits.
            return nil
        }
        
        var url = url
        if url.isEPUBURL, url.isFileURL {
            url = URL(string: "epub://" + url.path) ?? url
        }
        
        guard let realm = try? Realm(), let sharedRealm = try? Realm(configuration: realmConfiguration) else { return nil }
        
        let bookmark = realm.objects(Bookmark.self)
            .sorted(by: \.createdAt, ascending: false)
            .filter("url == %@", url.absoluteString)
            .first
        let history = realm.objects(HistoryRecord.self)
            .sorted(by: \.createdAt, ascending: false)
            .filter("url == %@", url.absoluteString)
            .first
        let feed = sharedRealm.objects(FeedEntry.self)
            .sorted(by: \.createdAt, ascending: false)
            .filter("url == %@", url.absoluteString)
            .first
        let candidates: [any ReaderContentModel] = [bookmark, history, feed].compactMap { $0 }
        var match = candidates.max(by: { $0.createdAt > $1.createdAt })
        if match == nil {
            let historyRecord = HistoryRecord()
            historyRecord.url = url
            //        historyRecord.isReaderModeByDefault
            historyRecord.updateCompoundKey()
            if persist {
                try! realm.write {
                    realm.add(historyRecord, update: .modified)
                }
            }
            match = historyRecord
        }
        if let match = match, url.isFileURL, url.contains(.plainText), let contents = try? String(contentsOf: url), let data = textToHTML(contents, forceRaw: true).readerContentData {
            safeWrite(match) { _, match in
                match.content = data
            }
        }
        return match
    }
    
    public static func load(urlString: String, realmConfiguration: Realm.Configuration) -> (any ReaderContentModel)? {
        guard let url = URL(string: urlString) else { return nil }
        return load(url: url, realmConfiguration: realmConfiguration)
    }
    
    public static func load(html: String, realmConfiguration: Realm.Configuration) -> (any ReaderContentModel)? {
        guard let realm = try? Realm(), let sharedRealm = try? Realm(configuration: DefaultRealmConfiguration.configuration) else { return nil }
        
        let data = html.readerContentData
        
        let bookmark = realm.objects(Bookmark.self)
            .sorted(by: \.createdAt, ascending: false)
            .where { $0.content == data }
            .first
//            .first(where: { $0.content == data })
        let history = realm.objects(HistoryRecord.self)
            .sorted(by: \.createdAt, ascending: false)
            .where { $0.content == data }
            .first
        let feed = sharedRealm.objects(FeedEntry.self)
            .sorted(by: \.createdAt, ascending: false)
            .where { $0.content == data }
            .first
        let candidates: [any ReaderContentModel] = [bookmark, history, feed].compactMap { $0 }
        
        if let match = candidates.max(by: { $0.createdAt < $1.createdAt }) {
            return match
        }
        
        let historyRecord = HistoryRecord()
        historyRecord.publicationDate = Date()
        historyRecord.content = data
//        historyRecord.isReaderModeByDefault = true
        historyRecord.updateCompoundKey()
        historyRecord.url = snippetURL(key: historyRecord.compoundKey) ?? historyRecord.url
        try! realm.write {
            realm.add(historyRecord, update: .modified)
        }
        return historyRecord
    }
    
    private static func docIsPlainText(doc: SwiftSoup.Document) -> Bool {
        return (
            ((doc.body()?.children().isEmpty()) ?? true)
            || ((doc.body()?.children().first()?.tagNameNormal() ?? "") == "pre" && doc.body()?.children().count == 1) )
    }
    
    private static func textToHTML(_ text: String, forceRaw: Bool = false) -> String {
        if forceRaw {
            return "<html><body>\(text.escapeHtml())</body></html>"
        } else if let doc = try? SwiftSoup.parse(text) {
            if docIsPlainText(doc: doc) {
                return "<html><body>\(text)</body></html>"
            } else {
                return text // HTML content
            }
        } else {
            let markdown = MarkdownParser.standard.parse(text.trimmingCharacters(in: .whitespacesAndNewlines))
            let html = PasteboardHTMLGenerator().generate(doc: markdown)
            return "<html><body>\(html)</body></html>"
        }
    }
    
    public static func snippetURL(key: String) -> URL? {
        return URL(string: "about:snippet?key=\(key)")
    }
    
    public static func load(text: String, realmConfiguration: Realm.Configuration) -> (any ReaderContentModel)? {
        return load(html: textToHTML(text, forceRaw: true), realmConfiguration: realmConfiguration)
    }
    
    public static func loadPasteboard(realmConfiguration: Realm.Configuration) -> (any ReaderContentModel)? {
        var match: (any ReaderContentModel)?
        
        #if os(macOS)
        let html = NSPasteboard.general.string(forType: .html)
        let text = NSPasteboard.general.string(forType: .string)
        #else
        let html = UIPasteboard.general.string
        let text: String? = html
        #endif
        
        if let html = html {
            if let doc = try? SwiftSoup.parse(html) {
                if docIsPlainText(doc: doc), let text = text {
                    match = load(html: textToHTML(text), realmConfiguration: realmConfiguration)
                } else {
                    match = load(html: html, realmConfiguration: realmConfiguration)
                }
                match = load(html: html, realmConfiguration: realmConfiguration)
            } else {
                match = load(html: textToHTML(html), realmConfiguration: realmConfiguration)
            }
        } else if let text = text {
            match = load(html: textToHTML(text), realmConfiguration: realmConfiguration)
        }
        if let match = match, let url = snippetURL(key: match.compoundKey) {
            safeWrite(match) { _, match in
                match.isFromClipboard = true
                match.url = url
            }
        }
        return match
    }
    
    public static func saveBookmark(text: String?, title: String?, url: URL, isFromClipboard: Bool, isReaderModeByDefault: Bool, realmConfiguration: Realm.Configuration) {
        if let text = text {
            _ = Bookmark.add(url: url, title: title ?? "", html: textToHTML(text), isFromClipboard: isFromClipboard, isReaderModeByDefault: isReaderModeByDefault, realmConfiguration: realmConfiguration)
        } else {
            _ = Bookmark.add(url: url, title: title ?? "", isFromClipboard: isFromClipboard, isReaderModeByDefault: isReaderModeByDefault, realmConfiguration: realmConfiguration)
        }
    }
    
    public static func saveBookmark(text: String, title: String?, url: URL?, isFromClipboard: Bool, isReaderModeByDefault: Bool, realmConfiguration: Realm.Configuration) {
        let html = Self.textToHTML(text)
        _ = Bookmark.add(url: url, title: title ?? "", html: html, isFromClipboard: isFromClipboard, isReaderModeByDefault: isReaderModeByDefault, realmConfiguration: realmConfiguration)
    }
}

/// Forked from: https://github.com/objecthub/swift-markdownkit/issues/6
open class PasteboardHTMLGenerator: HtmlGenerator {
    override open func generate(text: Text) -> String {
        var res = ""
        for (idx, fragment) in text.enumerated() {
            if (idx + 1) < text.count {
                let next = text[idx + 1]
                switch (fragment as TextFragment, next as TextFragment) {
                case (.softLineBreak, .text(let text)):
                    if text.starts(with: "　") || text.starts(with: "    ") {
                        res += "<br/><br/>" // TODO: Morph to paragraph
                        continue
                    }
                case (.softLineBreak, .softLineBreak):
                    res += "<br/><br/>" // TODO: Morph to paragraph
                    continue
                default:
                    break
                }
            }
            
            res += generate(textFragment: fragment)
        }
        return res
    }
    
//    override open func generate(textFragment fragment: TextFragment) -> String {
//        switch fragment {
//        case .softLineBreak:
//            return "<br/>"
//        default:
//            return super.generate(textFragment: fragment)
//        }
//    }
}
