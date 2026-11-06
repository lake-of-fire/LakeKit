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

    func writeTransferFile(in directory: URL = FileManager.default.temporaryDirectory) throws -> URL {
        // Receivers may read the file after the exporting closure returns.
        // Each materialization therefore retains its own URL and snapshot.
        let transferDirectory = directory.appendingPathComponent(
            "LakeKitZIPTransfer-\(UUID().uuidString)", isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: transferDirectory, withIntermediateDirectories: true
        )
        let fileURL = transferDirectory.appendingPathComponent(fileName)
        do {
            try content.write(to: fileURL, options: .atomic)
            return fileURL
        } catch {
            try? FileManager.default.removeItem(at: transferDirectory)
            throw error
        }
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
            let resultURL = try zip.writeTransferFile()
            return SentTransferredFile(resultURL, allowAccessingOriginalFile: true)
        } importing: { _ in
            throw TransferError.importFailed
        }
    }
}
