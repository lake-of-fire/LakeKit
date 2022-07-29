import Foundation

public extension String {
    func toUppercaseAtSentenceBoundary() -> String {
        var result = ""
        self.uppercased().enumerateSubstrings(in: self.startIndex..<self.endIndex, options: .bySentences) { (sub, _, _, _)  in
            result += String(sub!.prefix(1))
            result += String(sub!.dropFirst(1)).lowercased()
        }
        
        return result as String
    }
}
