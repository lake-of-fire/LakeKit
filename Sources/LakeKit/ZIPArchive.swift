import Foundation
import SwiftUI

public enum LakeKitFilenameSanitizer {
    private static let invalidFilenameCharacters = CharacterSet(charactersIn: "/\\?%*|\"<>:")
        .union(.controlCharacters)

    public static func sanitize(
        _ proposedName: String?,
        fallback: String = "Export",
        maxLength: Int = 100
    ) -> String {
        let trimmedName = proposedName?.trimmingCharacters(in: .whitespacesAndNewlines)
        var sanitized = sanitizeCore(trimmedName, maxLength: maxLength)
        if sanitized.isEmpty {
            sanitized = sanitizeCore(fallback, maxLength: maxLength)
        }
        if sanitized.isEmpty || sanitized == "." || sanitized == ".." {
            return "Export"
        }
        return sanitized
    }

    private static func sanitizeCore(_ value: String?, maxLength: Int) -> String {
        guard let value, !value.isEmpty else { return "" }

        var characters: [Character] = []
        characters.reserveCapacity(min(value.count, maxLength))
        var previousCharacterWasWhitespace = false

        for scalar in value.unicodeScalars {
            if invalidFilenameCharacters.contains(scalar) {
                characters.append("-")
                previousCharacterWasWhitespace = false
                continue
            }

            if CharacterSet.whitespacesAndNewlines.contains(scalar) {
                if !previousCharacterWasWhitespace {
                    characters.append(" ")
                    previousCharacterWasWhitespace = true
                }
                continue
            }

            characters.append(Character(scalar))
            previousCharacterWasWhitespace = false
        }

        var sanitized = String(characters).trimmingCharacters(in: .whitespacesAndNewlines)
        if sanitized.count > maxLength {
            sanitized = String(sanitized.prefix(maxLength))
        }

        return sanitized
    }
}

public enum TransferError: Error {
    case importFailed
}

public struct ZIPArchive: Codable {
    public let title: String
    public let content: Data

    public var exportFilenameBase: String {
        LakeKitFilenameSanitizer.sanitize(title, fallback: "Manabi Archive")
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
}
#endif

@available(iOS 16.0, macOS 13.0, *)
extension ZIPArchive: Transferable {
    public static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .zip,
                           shouldAttemptToOpenInPlace: false) { zip in
            let resultURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(zip.exportFilenameBase)
                .appendingPathExtension("zip")
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
