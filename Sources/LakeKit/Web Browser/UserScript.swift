import Foundation
import WebKit
import RealmSwift
import BigSyncKit

public class UserScript: Object, UnownedSyncableObject, ObjectKeyIdentifiable, Codable {
    public var needsSyncToServer: Bool {
        return false
    }

    @Persisted(primaryKey: true) public var id = UUID()
    @Persisted public var title = ""
    @Persisted public var script = ""
    @Persisted public var injectAtStart = false
    @Persisted public var mainFrameOnly = false
    @Persisted public var sandboxed = false
    
    @Persisted public var isArchived = true
    
    @Persisted public var opmlOwnerName: String? = nil
    @Persisted public var opmlURL: URL? = nil
    
    @Persisted public var modifiedAt: Date
    
    @Persisted public var isDeleted = false
    
    public var webKitUserScript: WKUserScript {
        return WKUserScript(source: script, injectionTime: injectAtStart ? .atDocumentStart : .atDocumentEnd, forMainFrameOnly: mainFrameOnly, in: WKContentWorld.world(name: id.uuidString))
    }
    
    
    public var isUserEditable: Bool {
        return opmlURL == nil
    }
}
