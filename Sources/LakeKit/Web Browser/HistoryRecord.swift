import Foundation
import RealmSwift

public class HistoryRecord: Bookmark {
    @Persisted public var lastVisitedAt = Date()
}
