import Foundation
import SwiftUI

public enum TransferError: Error {
    case importFailed
}

public enum FileNameSanitizer {
    public static func sanitizedBaseName(_ value: String, fallback: String = "File") -> String {
        let illegalCharacters = CharacterSet(charactersIn: "/\\:")
            .union(.newlines)
            .union(.controlCharacters)
        let sanitized = value
            .components(separatedBy: illegalCharacters)
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
        let fallback = fallback.isEmpty ? "File" : fallback
        let baseName = sanitized.isEmpty ? fallback : sanitized
        return String(baseName.prefix(180))
    }
}

public struct ZIPArchive: Codable {
    public let title: String
    public let content: Data
    public var fileBaseName: String {
        FileNameSanitizer.sanitizedBaseName(title, fallback: "Archive")
    }
    public var fileName: String {
        "\(fileBaseName).zip"
    }
    
    public init(title: String, content: Data) {
        self.title = title
        self.content = content
    }
}

#if os(iOS)
extension ZIPArchive: LakeKit.Shareable {
    public var pathExtension: String { "zip" }
    public var itemProvider: NSItemProvider? {
        do {
            let url = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("\(UUID().uuidString)")
                .appendingPathExtension(pathExtension)
            try content.write(to: url)
            return .init(contentsOf: url)
        } catch {
            return nil
        }
    }

    public var sharingItem: Any {
        itemProvider ?? content
    }
}
#endif

@available(iOS 16.0, macOS 13.0, *)
extension ZIPArchive: Transferable {
    public static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .zip,
                           shouldAttemptToOpenInPlace: false) { zip in
            let resultURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(zip.fileName)
            if FileManager.default.fileExists(atPath: resultURL.path) {
                try FileManager.default.removeItem(at: resultURL)
            }
            try zip.content.write(to: resultURL)
            return SentTransferredFile(resultURL, allowAccessingOriginalFile: true)
        } importing: { _ in
            throw TransferError.importFailed
        }
    }
}
