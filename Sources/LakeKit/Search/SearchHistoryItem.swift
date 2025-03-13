//import Foundation
//import RealmSwift
//import BigSyncKit
//import RealmSwiftGaps
//
//public class SearchHistoryItem: Object, UnownedSyncableObject, ChangeMetadataRecordable {
//    @Persisted(primaryKey: true) public var id = UUID()
//    
//    @Persisted public var searchText = ""
//    @Persisted public var userScriptIDs: RealmSwift.List<UUID>
//    
//    @Persisted public var lastSearchedAt = Date()
//    
//    @Persisted public var createdAt = Date()
//    @Persisted public var modifiedAt = Date()
//    @Persisted public var isDeleted = false
//    
//    public var needsSyncToServer: Bool {
//        return false
//    }
//    
//    public override init() {
//        super.init()
//    }
//}
//
//extension SearchHistoryItem: SearchSuggestion {
//    public var searchSuggestionText: String {
//        return searchText
//    }
//    
//    public var searchSuggestionIconImageName: String {
//        return "magnifyingglass"
//    }
//}
