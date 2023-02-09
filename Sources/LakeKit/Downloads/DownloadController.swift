import Foundation
import SwiftUI
import Combine
import Compression
import BackgroundAssets

public class Downloadable: ObservableObject, Identifiable, Hashable {
    public let url: URL
    let mirrorURL: URL?
    public let name: String
    public let localDestination: URL
    var isFromBackgroundAssetsDownloader: Bool? = nil

    @Published internal var downloadProgress: URLResourceDownloadTaskProgress = .uninitiated
    @Published public var isFailed = false
    @Published public var isActive = false
    @Published public var isFinishedDownloading = false
    @Published public var isFinishedProcessing = false
    
    private var cancellables = Set<AnyCancellable>()
    
    public var id: String {
        return url.absoluteString
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public var lastDownloaded: Date? {
        get {
            return UserDefaults.standard.object(forKey: "fileLastDownloadedDate:\(url.absoluteString)") as? Date
        }
        set {
            if let newValue = newValue {
                UserDefaults.standard.set(newValue, forKey: "fileLastDownloadedDate:\(url.absoluteString)")
            } else {
                UserDefaults.standard.removeObject(forKey: "fileLastDownloadedDate:\(url.absoluteString)")
            }
        }
    }
    
    public init(url: URL, mirrorURL: URL?, name: String, localDestination: URL, isFromBackgroundAssetsDownloader: Bool? = nil) {
        self.url = url
        self.mirrorURL = mirrorURL
        self.name = name
        self.localDestination = localDestination
        self.isFromBackgroundAssetsDownloader = isFromBackgroundAssetsDownloader
    }
    
    public static func == (lhs: Downloadable, rhs: Downloadable) -> Bool {
        return lhs.url == rhs.url && lhs.mirrorURL == rhs.mirrorURL && lhs.name == rhs.name && lhs.localDestination == rhs.localDestination
    }
    
    public var compressedFileURL: URL {
        return localDestination.appendingPathExtension("br")
    }
    
    func existsLocally() -> Bool {
        return FileManager.default.fileExists(atPath: localDestination.path) || FileManager.default.fileExists(atPath: compressedFileURL.path)
    }
    
    func download() -> URLResourceDownloadTask {
        let destination = url.pathExtension == "br" ? compressedFileURL : localDestination
        let task = URLResourceDownloadTask(session: URLSession.shared, url: url, destination: destination)
        task.publisher.receive(on: DispatchQueue.main).sink(receiveCompletion: { [weak self] completion in
            switch completion {
            case .failure(let error):
                self?.isFailed = true
                self?.isFinishedDownloading = false
                self?.isActive = false
                self?.downloadProgress = .completed(destinationLocation: nil, error: error)
            case .finished:
                self?.lastDownloaded = Date()
                self?.isFailed = false
                self?.isActive = false
                self?.isFinishedDownloading = true
            }
        }, receiveValue: { [weak self] progress in
            self?.isActive = true
            self?.downloadProgress = progress
            switch progress {
            case .completed(let destinationLocation, let urlError):
                guard urlError == nil, let destinationLocation = destinationLocation else {
                    self?.isFailed = true
                    self?.isFinishedDownloading = false
                    self?.isActive = false
                    return
                }
                self?.lastDownloaded = Date()
                self?.isFinishedDownloading = true
                self?.isActive = false
                self?.isFailed = false
            default:
                break
            }
        }).store(in: &cancellables)
        task.resume()
        return task
    }
    
    func decompressIfNeeded() throws {
        if FileManager.default.fileExists(atPath: compressedFileURL.path) {
            let data = try Data(contentsOf: compressedFileURL)
            let decompressed = try data.decompressed(from: COMPRESSION_BROTLI)
            try decompressed.write(to: localDestination, options: .atomic)
            do {
                try FileManager.default.removeItem(at: compressedFileURL)
            } catch {
                print("Error removing compressedFileURL \(compressedFileURL)")
            }
        } else {
            print("No file exists to decompress at \(compressedFileURL)")
        }
    }
}

@available(macOS 13.0, iOS 16.1, *)
public extension Downloadable {
    func backgroundAssetDownload(applicationGroupIdentifier: String) -> BAURLDownload? {
        return BAURLDownload(identifier: localDestination.absoluteString, request: URLRequest(url: url), applicationGroupIdentifier: applicationGroupIdentifier, priority: .max)
    }
}

public class DownloadController: NSObject, ObservableObject {
    public static var shared: DownloadController = {
        let controller = DownloadController()
        Task.detached { [weak controller] in
            if #available(macOS 13.0, iOS 16.1, *) {
                BADownloadManager.shared.delegate = controller
            } else { }
        }
        return controller
    }()
    
    @Published public var assuredDownloads = Set<Downloadable>()
    @Published public var activeDownloads = Set<Downloadable>()
    @Published public var finishedDownloads = Set<Downloadable>()
    @Published public var failedDownloads = Set<Downloadable>()
    
    public var unfinishedDownloads: [Downloadable] {
        let downloads: [Downloadable] = Array(activeDownloads) + Array(failedDownloads)
        return downloads.sorted(by: { $0.name > $1.name })
    }
    
    private var observation: NSKeyValueObservation?
    private var cancellables = Set<AnyCancellable>()
    
    public override init() {
        super.init()
        
        
    }
}

public extension DownloadController {
    func ensureDownloaded(_ downloads: Set<Downloadable>) {
        for download in downloads {
            assuredDownloads.insert(download)
        }
        ensureDownloaded()
    }
}

extension DownloadController {
    func ensureDownloaded() {
        for download in assuredDownloads {
            if download.existsLocally() {
                finishDownload(download)
                checkFileModifiedAt(download: download) { [weak self] modified, _ in
                    if modified {
                        self?.download(download)
                    }
                }
            } else {
                self.download(download)
            }
        }
    }
    
    func download(_ download: Downloadable) {
        download.$isActive.removeDuplicates().receive(on: DispatchQueue.main).sink { [weak self] isActive in
            if isActive {
                self?.activeDownloads.insert(download)
            } else {
                self?.activeDownloads.remove(download)
            }
        }.store(in: &cancellables)
        download.$isFailed.removeDuplicates().receive(on: DispatchQueue.main).sink { [weak self] isFailed in
            if isFailed {
                self?.failedDownloads.insert(download)
                self?.activeDownloads.remove(download)
                self?.finishedDownloads.remove(download)
            } else {
                self?.failedDownloads.remove(download)
            }
        }.store(in: &cancellables)
        download.$isFinishedDownloading.removeDuplicates().receive(on: DispatchQueue.main).sink { [weak self] isFinishedDownloading in
            if isFinishedDownloading {
                self?.finishedDownloads.insert(download)
                self?.activeDownloads.remove(download)
                self?.failedDownloads.remove(download)
                download.lastDownloaded = Date()
                if !(download.isFromBackgroundAssetsDownloader ?? true) {
                    Task { @MainActor [weak self] in
                        try? await self?.cancelInProgressDownloads(inDownloadExtension: true)
                    }
                }
                self?.finishDownload(download)
            } else {
                self?.finishedDownloads.remove(download)
            }
        }.store(in: &cancellables)

        Task.detached {
            let allTasks = await URLSession.shared.allTasks
            if allTasks.first(where: { $0.taskDescription == download.url.absoluteString }) != nil {
                // Task exists.
                return
            }
            
            if #available(macOS 13, iOS 16.1, *) {
                Task.detached {
                    do {
                        if let baDL = download.backgroundAssetDownload(applicationGroupIdentifier: "group.io.manabi.shared"), try await BADownloadManager.shared.currentDownloads.contains(baDL) {
                            try BADownloadManager.shared.startForegroundDownload(baDL)
                            return
                        }
                    } catch {
                        print("Unable to download background asset...")
                    }
                }
            } else { }
            
            download.isFromBackgroundAssetsDownloader = false
            _ = download.download()
        }
    }
    
    func cancelInProgressDownloads(inApp: Bool = false, inDownloadExtension: Bool = false) async throws {
        if inApp {
            let allTasks = await URLSession.shared.allTasks
            for task in allTasks.filter({ task in assuredDownloads.contains(where: { $0.localDestination.absoluteString == (task.taskDescription ?? "") }) }) {
                task.cancel()
            }
        }
        if inDownloadExtension {
            if #available(iOS 16.1, macOS 13, *) {
                for download in try await BADownloadManager.shared.currentDownloads {
                    try BADownloadManager.shared.cancel(download)
                }
            }
        }
    }
    
    public func finishDownload(_ download: Downloadable) {
        do {
            try download.decompressIfNeeded()

            // Confirm non-empty
            let resourceValues = try download.localDestination.resourceValues(forKeys: [.fileSizeKey])
            guard let fileSize = resourceValues.fileSize, fileSize > 0 else {
                activeDownloads.remove(download)
                finishedDownloads.remove(download)
                failedDownloads.insert(download)
                return
            }
//              print("File size = " + ByteCountFormatter().string(fromByteCount: Int64(fileSize)))
            
            Task { @MainActor [weak self] in
                self?.failedDownloads.remove(download)
                self?.activeDownloads.remove(download)
                self?.finishedDownloads.insert(download)
                download.isFinishedProcessing = true
            }
        } catch {
            Task { @MainActor [weak self] in
                self?.failedDownloads.insert(download)
                self?.activeDownloads.remove(download)
                self?.finishedDownloads.remove(download)
            }
            try? FileManager.default.removeItem(at: download.compressedFileURL)
            try? FileManager.default.removeItem(at: download.localDestination)
        }
    }
    
    /// Checks if file at given URL is modified.
    /// Using "Last-Modified" header value to compare it with given date.
    func checkFileModifiedAt(download: Downloadable, completion: @escaping (Bool, Date?) -> Void) {
        var request = URLRequest(url: download.url)
        request.httpMethod = "HEAD"
        URLSession.shared.dataTask(with: request, completionHandler: { (_, response, error) in
            guard let httpURLResponse = response as? HTTPURLResponse,
                  httpURLResponse.statusCode == 200,
                  let modifiedDateString = httpURLResponse.allHeaderFields["Last-Modified"] as? String,
                  error == nil else {
                completion(false, nil)
                return
            }
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .long
            dateFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
            guard let modifiedDate = dateFormatter.date(from: modifiedDateString) else {
                completion(false, nil)
                return
            }
            
            if modifiedDate > download.lastDownloaded ?? Date(timeIntervalSince1970: 0) {
                completion(true, modifiedDate)
                return
            }
            
            completion(false, nil)
        }).resume()
    }
}

@available(macOS 13.0, iOS 16.1, *)
extension DownloadController: BADownloadManagerDelegate {
    public func download(_ download: BADownload, didWriteBytes bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite totalExpectedBytes: Int64) {
        guard let downloadable = assuredDownloads.downloadable(forDownload: download) else { return }
        let progress = Progress(totalUnitCount: totalExpectedBytes)
        progress.completedUnitCount = totalBytesWritten
        downloadable.downloadProgress = .downloading(progress: progress)
        downloadable.isFromBackgroundAssetsDownloader = true
        finishedDownloads.remove(downloadable)
        failedDownloads.remove(downloadable)
        activeDownloads.insert(downloadable)
        Task { @MainActor in
            do {
                try await cancelInProgressDownloads(inApp: true)
            } catch {
            }
        }
    }
    
    public func downloadDidBegin(_ download: BADownload) {
        guard let downloadable = assuredDownloads.downloadable(forDownload: download) else { return }
        downloadable.downloadProgress = .downloading(progress: Progress())
        downloadable.isFromBackgroundAssetsDownloader = true
        finishedDownloads.remove(downloadable)
        failedDownloads.remove(downloadable)
        activeDownloads.insert(downloadable)
    }
    
    public func download(_ download: BADownload, finishedWithFileURL fileURL: URL) {
        BADownloadManager.shared.withExclusiveControl { [weak self] acquiredLock, error in
            guard acquiredLock, error == nil else { return }
            if let downloadable = self?.assuredDownloads.downloadable(forDownload: download) {
                downloadable.isFromBackgroundAssetsDownloader = true
                let destination = downloadable.url.pathExtension == "br" ? downloadable.compressedFileURL : downloadable.localDestination
                do {
                    try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
                    try FileManager.default.moveItem(at: fileURL, to: destination)
                } catch { }
                Task.detached { [weak self] in
                    self?.finishDownload(downloadable)
                    Task { @MainActor [weak self] in
                        try await self?.cancelInProgressDownloads(inApp: true)
                    }
                }
            }
        }
    }
    
    public func download(_ download: BADownload, failedWithError error: Error) {
        do {
            if let downloadable = assuredDownloads.downloadable(forDownload: download) {
                downloadable.downloadProgress = .completed(destinationLocation: nil, error: error)
                finishedDownloads.remove(downloadable)
                activeDownloads.remove(downloadable)
                failedDownloads.insert(downloadable)
            }
            try BADownloadManager.shared.startForegroundDownload(download)
        } catch { }
    }
    
}

@available(macOS 13.0, iOS 16.1, *)
public extension Set<Downloadable> {
    func downloadable(forDownload download: BADownload) -> Downloadable? {
        for downloadable in DownloadController.shared.assuredDownloads {
            if downloadable.localDestination.absoluteString == download.identifier {
                return downloadable
            }
        }
        return nil
    }
}
