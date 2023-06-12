import Foundation
import RealmSwift

public class Bookmark: Object, ReaderContentModel {
    @Persisted(primaryKey: true) public var compoundKey = ""
    
    @Persisted public var url = URL(string: "about:blank")!
    @Persisted public var title = ""
    @Persisted public var imageUrl: URL?
    @Persisted public var publicationDate: Date?
    @Persisted public var isFromClipboard = false
    
    // Caches
    /// Deprecated, use `content` via `html`.
    @Persisted public var htmlContent: String?
    @Persisted public var content: Data?
    @Persisted public var isReaderModeAvailable = false
    
    // Feed entry metadata.
    @Persisted public var rssURLs = RealmSwift.List<URL>()
    @Persisted public var rssTitles = RealmSwift.List<String>()
    @Persisted public var isRSSAvailable = false
    @Persisted public var voiceFrameUrl: URL?
    @Persisted public var voiceAudioURLs = RealmSwift.List<URL>()
    @Persisted public var redditTranslationsUrl: URL?
    @Persisted public var redditTranslationsTitle: String?
    
    // Feed options.
    @Persisted public var isReaderModeByDefault = false
    @Persisted public var rssContainsFullContent = false
    @Persisted public var meaningfulContentMinLength = 0
    @Persisted public var injectEntryImageIntoHeader = false
    @Persisted public var displayPublicationDate = true
    
    @Persisted public var createdAt = Date()
    @Persisted public var isDeleted = false
    
    public var htmlToDisplay: String? { html }
    public var imageURLToDisplay: URL? { imageUrl }
    
    
    public func configureBookmark(_ bookmark: Bookmark) {
        let url = url
        safeWrite { realm in
            for historyRecord in realm.objects(HistoryRecord.self).where({ ($0.bookmark == nil || $0.bookmark.isDeleted) && !$0.isDeleted }).filter({ $0.url == url }) {
                historyRecord.bookmark = bookmark
            }
        }
    }
}

public extension Bookmark {
    static func add(url: URL? = nil, title: String = "", imageUrl: URL? = nil, html: String? = nil, content: Data? = nil, publicationDate: Date? = nil, isFromClipboard: Bool, isReaderModeByDefault: Bool, realmConfiguration: Realm.Configuration) -> Bookmark {
        let realm = try! Realm(configuration: realmConfiguration)
        let pk = Bookmark.makePrimaryKey(url: url, html: html)
        if let bookmark = realm.object(ofType: Bookmark.self, forPrimaryKey: pk) {
            try! realm.write {
                bookmark.title = title
                bookmark.imageUrl = imageUrl
                if let html = html {
                    bookmark.html = html
                } else if let content = content {
                    bookmark.content = content
                }
                bookmark.publicationDate = publicationDate
                bookmark.isFromClipboard = isFromClipboard
                bookmark.isReaderModeByDefault = isReaderModeByDefault
                bookmark.isDeleted = false
            }
            return bookmark
        } else {
            let bookmark = Bookmark()
            if let html = html {
                bookmark.html = html
            } else if let content = content {
                bookmark.content = content
            }
            if let url = url {
                bookmark.url = url
                bookmark.updateCompoundKey()
            } else {
                bookmark.updateCompoundKey()
                bookmark.url = ReaderContentLoader.snippetURL(key: bookmark.compoundKey) ?? bookmark.url
            }
            bookmark.title = title
            bookmark.imageUrl = imageUrl
            bookmark.publicationDate = publicationDate
            bookmark.isFromClipboard = isFromClipboard
            bookmark.isReaderModeByDefault = isReaderModeByDefault
            try! realm.write {
                realm.add(bookmark, update: .modified)
            }
            return bookmark
        }
    }
    
//    func fetchRecords() -> [HistoryRecord] {
//        var limitedRecords: [HistoryRecord] = []
//        let records = realm.objects(HistoryRecord.self).filter("isDeleted == false").sorted(byKeyPath: "lastVisitedAt", ascending: false)
//        for idx in 0..<100 {
//            limitedRecords.append(records[idx])
//        }
//        return limitedRecords
//    }
    
    static func removeAll() {
        let realm = try! Realm()
        try! realm.write {
            realm.objects(self).setValue(true, forKey: "isDeleted")
        }
    }
}
