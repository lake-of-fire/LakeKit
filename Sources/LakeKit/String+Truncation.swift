import Foundation

public extension String {
    func truncate(_ length: Int, trailing: String? = "…") -> String {
        return (self.count > length) ? self.prefix(length) + (trailing ?? "") : self
    }
}
