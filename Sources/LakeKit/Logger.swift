import SwiftUI
import Logging
import Puppy
import OSLog
import ZIPFoundation

fileprivate func bundleIdentifier() -> String {
    return (Bundle(for: Logger.self).bundleIdentifier ?? "")
}

public class Logger/*: ObservableObject*/ {
    public static let shared = Logger()
    public let logger: Logging.Logger
    
    private var fileLogger: FileRotationLogger?
    
    init() {
        (logger, fileLogger) = Self.makeLogger()
        
        do {
            try createLogDirectory()
        } catch {
            print("Could not create the log directory: \(error.localizedDescription)")
        }
    }
    
    /// Deletes all log files from the log directory.
    public func clearLogFiles() {
        do {
            let url = try Self.logDirectoryURL()
            fileLogger?.delete(url)
            print("All log files deleted from \(url.path)")
        } catch {
            print("Failed to clear log files: \(error)")
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
    
    static func makeLogger() -> (Logging.Logger, FileRotationLogger?) {
        var puppy = Puppy()
#if DEBUG
        puppy.add(makeConsoleLogger())
        puppy.add(ConsoleLogger("print", logFormat: ConsoleLogFormatter()))
#endif
        var fileLogger: FileRotationLogger?
        do {
            fileLogger = try makeFileLogger()
            if let fileLogger {
                puppy.add(fileLogger)
            }
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
        
        return (
            Logging.Logger(label: bundleIdentifier() + ".swiftlog"),
            fileLogger
        )
    }
    
    func getCurrentLogs() -> [URL] {
        do {
            let url = try Self.logDirectoryURL()
            let items = try FileManager.default.contentsOfDirectory(atPath: url.path)
            return items.compactMap { url.appendingPathComponent($0) } .sorted(by: { $0.lastPathComponent > $1.lastPathComponent })
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
            maxFileSize: UInt64((30 * Double(1_024 * 1_024)).rounded()),
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
    @Published public var logs: [TransferableLog]?
    @Published public var logsText: String?
    //    @Published public var clippedReversedLogsText: String?
    @Published public var clippedLogsText: String?
    @Published public var logsZIPArchive: ZIPArchive?
    @Published private var loadTask: Task<Void, Error>? = nil
    
    private let logger: Logger
    
    // MARK: Initialization
    public init(logger: Logger = Logger.shared) {
        self.logger = logger
    }
    
    public func clearLogs() async {
        logger.clearLogFiles()
        await load()
    }
    
    public var isLoading: Bool {
        if let task = loadTask {
            return !task.isCancelled
        }
        return false
    }
    
    public func load() async {
        loadTask?.cancel()
        
        let newTask = Task.detached(priority: .utility) { [weak self] in
            guard let self else { return }
            let logs = logger.getCurrentLogs().map { url in
                TransferableLog(url: url, name: url.lastPathComponent)
            }
            
            let logsCount = logs.count
            let fileContents = logs.compactMap { log -> String? in
                guard let content = try? String(contentsOf: log.url) else { return nil }
                if logsCount == 1 {
                    return content
                }
                return "LOG: \(log.name) (\(log.url.lastPathComponent))\n\n" + content
            }
            let logsText = fileContents.joined(separator: "\n\n")
            
            //            let clippedReversedFileContents = logs.compactMap { log -> String? in
            //                guard let content = try? String(contentsOf: log.url)
            //                    .split(separator: "\n")
            //                    .suffix(2000)
            //                    .reversed()
            //                    .joined(separator: "\n") else { return nil }
            //                if logsCount == 1 {
            //                    return content
            //                }
            //                return "LOG: \(log.name) (\(log.url.lastPathComponent))\n\n" + content
            //            }
            //            let clippedReversedLogsText = clippedReversedFileContents.joined(separator: "\n\n")
            let clippedLogsText = String(logsText.suffix(Int((0.75 * Double(1_024 * 1_024)).rounded())))
            
            try await { @MainActor [weak self] in
                guard let self else { return }
                try Task.checkCancellation()
                self.logs = logs
                self.logsText = logsText
                self.clippedLogsText = clippedLogsText
                //                self.clippedReversedLogsText = clippedReversedLogsText
            }()
            
            do {
                let archive = try await withCheckedThrowingContinuation { continuation in
                    do {
                        try Task.checkCancellation()
                        let logsData = Data(logsText.utf8)
                        guard let archive = Archive(accessMode: .create) else {
                            throw NSError(domain: "LoggingViewModel", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to initialize in-memory ZIP archive."])
                        }
                        let progress = Progress(totalUnitCount: Int64(logsData.count))
                        try archive.addEntry(
                            with: "ManabiReaderLogs.txt",
                            type: .file,
                            uncompressedSize: Int64(logsData.count),
                            modificationDate: Date(),
                            permissions: nil,
                            compressionMethod: .deflate,
                            progress: progress
                        ) { position, size -> Data in
                            if Task.isCancelled {
                                progress.cancel()
                            }
                            let start = Int(position)
                            return logsData.subdata(in: start..<(start + size))
                        }
                        guard let zipData = archive.data else {
                            throw NSError(domain: "LoggingViewModel", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to get archive data."])
                        }
                        continuation.resume(
                            returning: ZIPArchive(
                                title: "ManabiReaderLogs",
                                content: zipData
                            )
                        )
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
                try await { @MainActor [weak self] in
                    guard let self else { return }
                    try Task.checkCancellation()
                    self.logsZIPArchive = archive
                }()
            } catch {
                Logger.shared.logger.error("LoggingViewModel error: \(error)")
            }
        }
        
        loadTask = newTask
        try? await newTask.value
        loadTask = nil
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

struct ConsoleLogFormatter: LogFormattable {
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
        return "[\(level)] \(message)"
    }
    }
