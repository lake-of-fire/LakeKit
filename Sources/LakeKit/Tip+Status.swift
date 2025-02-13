import Foundation
import TipKit

@available(iOS 17, macOS 14, *)
public extension Tip {
    var isInvalidated: Bool {
        switch status {
        case .available, .pending:
            return false
        case .invalidated(_):
            return true
        }
    }
}
