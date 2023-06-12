import Foundation
import RealmSwift

public class HistoryRecord: Bookmark {
    @Persisted public var lastVisitedAt = Date()
    
    @Persisted public var bookmark: Bookmark?
}

public struct OptionalBookmarkComparator: SortComparator {
    public var order: SortOrder = .forward
    
    public func compare(_ lhs: Bookmark?, _ rhs: Bookmark?) -> ComparisonResult {
        let result: ComparisonResult
        switch (lhs, rhs) {
        case (nil, nil): result = .orderedSame
        case (.some, nil): result = .orderedDescending
        case (nil, .some): result = .orderedAscending
        case let (lhs?, rhs?):
            result = lhs.createdAt.compare(rhs.createdAt)
        }
        return order == .forward ? result : result.reversed
    }
}

fileprivate extension ComparisonResult {
    var reversed: ComparisonResult {
        switch self {
        case .orderedAscending: return .orderedDescending
        case .orderedSame: return .orderedSame
        case .orderedDescending: return .orderedAscending
        }
    }
}
