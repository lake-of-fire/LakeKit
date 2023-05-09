import Foundation
import UniformTypeIdentifiers

// From: https://stackoverflow.com/questions/69540672/ios15-uttype-deprecations-for-url-extension
public extension URL {
    var mimeType: String {
        return UTType(filenameExtension: self.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
    }
    
    func contains(_ uttype: UTType) -> Bool {
        return UTType(mimeType: self.mimeType)?.conforms(to: uttype) ?? false
    }
}
