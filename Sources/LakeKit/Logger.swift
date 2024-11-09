import SwiftUI
import Logging
import Puppy
import OSLog
import ZIPFoundation

fileprivate func bundleIdentifier() -> String {
    return (Bundle(for: Logger.self).bundleIdentifier ?? "")
}

public class Logger: ObservableObject {
    public static let shared = Logger()
    public let logger: Logging.Logger
    
    init() {
        logger = Self.makeLogger()
        
        do {
            try createLogDirectory()
        } catch {
            print("Could not create the log directory: \(error.localizedDescription)")
        }
    }
    
    // MARK: Methods
    // This method throws in theory, but not in practice.
    static func logDirectoryURL() throws -> URL {
        var url = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true)
        url.appendPathComponent("logs")
        return url
    }
    
    func createLogDirectory() throws {
        let url = try Self.logDirectoryURL()
        if !FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.createDirectory(
                at: url,
                withIntermediateDirectories: true,
                attributes: nil)
        }
    }
    
    static func makeLogger() -> Logging.Logger {
        var puppy = Puppy()
#if DEBUG
        puppy.add(makeConsoleLogger())
#endif
        do {
            puppy.add(try makeFileLogger())
        } catch {
            // If the logger can't be created we just log the error through OSLog
            // and create an empty logger.
            print("Could not create the file logger: \(error)")
        }
        
        LoggingSystem.bootstrap { label in
            var handler = PuppyLogHandler(label: label, puppy: puppy)
            // Set the logging level.
#if DEBUG
            handler.logLevel = .trace
#else
            handler.logLevel = .info
#endif
            return handler
        }
        
        return Logging.Logger(label: bundleIdentifier() + ".swiftlog")
    }
    
    func getCurrentLogs() -> [URL] {
        do {
            let url = try Self.logDirectoryURL()
            let items = try FileManager.default.contentsOfDirectory(atPath: url.path)
            return items.compactMap { url.appendingPathComponent($0) }
        } catch {
            print("Could not list the logs: \(error)")
            return []
        }
    }
    
    // MARK: Private Methods
#if DEBUG
    static private func makeConsoleLogger() -> OSLogger {
        OSLogger(bundleIdentifier() + ".console", logFormat: OSLogFormatter())
    }
#endif
    
    static private func makeFileLogger() throws -> FileRotationLogger {
        let url = try Self.logDirectoryURL()
        let fileURL = url.appendingPathComponent("default.log")
        let rotationConfig = RotationConfig(
            suffixExtension: .date_uuid,
            maxFileSize: 2 * 1_024 * 1_024,
            maxArchivedFilesCount: 1)
        
#if DEBUG
        let logLevel: LogLevel = .trace
#else
        let logLevel: LogLevel = .info
#endif
        
        return try FileRotationLogger(
            bundleIdentifier() + ".file",
            logLevel: logLevel,
            logFormat: FileLogFormatter(),
            fileURL: fileURL,
            rotationConfig: rotationConfig)
    }
    
    // MARK: Inner Types
    struct FileLogFormatter: LogFormattable {
        private let dateFormat: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSSSSZ"
            return formatter
        }()
        
        // swiftlint:disable:next function_parameter_count
        func formatMessage(
            _ level: LogLevel,
            message: String,
            tag: String,
            function: String,
            file: String,
            line: UInt,
            swiftLogInfo: [String: String],
            label: String,
            date: Date,
            threadID: UInt64
        ) -> String {
            let date = dateFormat.string(from: date)
            let fileName = fileName(file)
            
            // swiftlint:disable:next line_length
            return "\(date) \(bundleIdentifier())[\(threadID)] [\(level)] \(fileName)#L.\(line) \(function) \(message)"
        }
    }
    
    struct OSLogFormatter: LogFormattable {
        private let dateFormat: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSSSSZ"
            return formatter
        }()
        
        // swiftlint:disable:next function_parameter_count
        func formatMessage(
            _ level: LogLevel,
            message: String,
            tag: String,
            function: String,
            file: String,
            line: UInt,
            swiftLogInfo: [String: String],
            label: String,
            date: Date,
            threadID: UInt64
        ) -> String {
            let fileName = fileName(file)
            return "\(fileName)#L.\(line) \(function) \(message)"
        }
    }
}

@MainActor
public class LoggingViewModel: ObservableObject {
    @Published public var logs: [TransferableLog] = []
    @Published public var logsText = ""
    
    private let logger: Logger
    
    // MARK: Initialization
    public init(logger: Logger = Logger.shared) {
        self.logger = logger
    }

    public func load() async {
        logs = logger.getCurrentLogs().map { url in
            TransferableLog(url: url, name: url.lastPathComponent)
        }
        
        let fileContents = logs.compactMap { log -> String? in
            guard let content = try? String(contentsOf: log.url) else { return nil }
            return "LOG: \(log.name) (\(log.url.lastPathComponent))\n\n" + content
        }
        
        logsText = fileContents.joined(separator: "\n\n")
    }
}

public struct TransferableLog: Hashable, Transferable {
    // MARK: Properties
    /// The URL on-disk.
    public let url: URL
    
    /// The name of the log.
    public let name: String
    
    @available(iOS 16, macOS 13, *)
    public static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .text) { transferable in
            SentTransferredFile(transferable.url)
        }
    }
}

extension Logger {
    public func writeLogFile() {
        let fileManager = FileManager.default
        
        do {
            // Create an in-memory ZIP archive
            guard let archive = Archive(accessMode: .create) else {
                print("Failed to initialize in-memory ZIP archive.")
                return
            }
            
            // Add log files to the archive
            try getCurrentLogs().forEach { logFileURL in
                if fileManager.fileExists(atPath: logFileURL.path) {
                    try archive.addEntry(with: logFileURL.lastPathComponent, relativeTo: logFileURL.deletingLastPathComponent(), compressionMethod: .deflate)
                }
            }
            
            // Retrieve the archive data from the in-memory archive
            guard let zipData = archive.data else {
                print("In-memory ZIP archive creation failed.")
                return
            }
            
            // Define the path for the ZIP file in the documents directory
            let documentsDirectory = try fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            let zipFileURL = documentsDirectory.appendingPathComponent("ManabiReaderLogs.zip")
            
            // Write ZIP file to disk, overwriting if it exists
            try zipData.write(to: zipFileURL, options: .atomic)
            print("Successfully wrote ZIP file to disk at \(zipFileURL.path)")
            
        } catch {
            print("Failed to create or write ZIP archive: \(error)")
        }
    }
}
