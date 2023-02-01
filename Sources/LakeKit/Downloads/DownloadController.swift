import Foundation
import SwiftUI
import Combine
import Compression
import BackgroundAssets

public class Downloadable: ObservableObject, Identifiable, Hashable {
    let url: URL
    let mirrorURL: URL?
    public let name: String
    public let localDestination: URL
    public var tempLocation: URL?

    @Published public var downloadProgress: URLResourceDownloadTaskProgress = .uninitiated
    @Published var isFinishedProcessing = false
    
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
    
    public init(url: URL, mirrorURL: URL?, name: String, localDestination: URL) {
        self.url = url
        self.mirrorURL = mirrorURL
        self.name = name
        self.localDestination = localDestination
    }
    
    public static func == (lhs: Downloadable, rhs: Downloadable) -> Bool {
        return lhs.url == rhs.url && lhs.mirrorURL == rhs.mirrorURL && lhs.name == rhs.name && lhs.localDestination == rhs.localDestination
    }
    
    var compressedFileURL: URL {
        return localDestination.appendingPathExtension(".br")
    }
    
    func existsLocally() -> Bool {
        return FileManager.default.fileExists(atPath: localDestination.path) || FileManager.default.fileExists(atPath: compressedFileURL.path)
    }
    
    func download() -> URLResourceDownloadTask {
        let task = URLResourceDownloadTask(session: URLSession.shared, url: url)
        task.publisher.sink(receiveCompletion: { _ in
        }, receiveValue: { [weak self] progress in
            self?.downloadProgress = progress
        }).store(in: &cancellables)
        return task
    }
    
    func decompressIfNeeded() throws {
        if FileManager.default.fileExists(atPath: compressedFileURL.path) {
            let data = try Data(contentsOf: compressedFileURL)
            let decompressed = try data.decompressed(from: COMPRESSION_BROTLI)
            try decompressed.write(to: localDestination, options: .atomic)
            do {
                try FileManager.default.removeItem(at: compressedFileURL)
            } catch { }
        }
    }
    
    func moveToDestination() throws {
        guard let tempLocation = tempLocation else { return }
        if tempLocation.pathExtension == "br" {
            try FileManager.default.moveItem(at: tempLocation, to: compressedFileURL)
        } else {
            try FileManager.default.moveItem(at: tempLocation, to: localDestination)
        }
        self.tempLocation = nil
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
        if #available(macOS 13.0, iOS 16.1, *) {
            BADownloadManager.shared.delegate = controller
        } else { }
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
        Task {
            let allTasks = await URLSession.shared.allTasks
            if allTasks.first(where: { $0.taskDescription == download.url.absoluteString }) != nil {
                // Task exists.
                return
            }
            
            if #available(macOS 13, iOS 16.1, *) {
                do {
                    if let baDL = download.backgroundAssetDownload(applicationGroupIdentifier: "group.io.manabi.shared"), try await BADownloadManager.shared.currentDownloads.contains(baDL) {
                        try BADownloadManager.shared.startForegroundDownload(baDL)
                        return
                    }
                } catch { }
            } else {
            }
            
            let task = download.download()
            Task { @MainActor [weak self] in
                self?.activeDownloads.insert(download)
                self?.finishedDownloads.remove(download)
                let sink = task.publisher.sink { [weak self] completion in
                    switch completion {
                    case .failure(_):
                        self?.failedDownloads.insert(download)
                        self?.activeDownloads.remove(download)
                    case .finished:
                        self?.finishedDownloads.insert(download)
                        self?.activeDownloads.remove(download)
                    }
                } receiveValue: { progress in
                    switch progress {
                    case .completed(let destinationLocation, let urlError):
                        guard urlError == nil, let destinationLocation = destinationLocation else {
                            self?.failedDownloads.insert(download)
                            self?.activeDownloads.remove(download)
                            return
                        }
                        download.tempLocation = destinationLocation
                        Task.detached { [weak self] in
                            download.lastDownloaded = Date()
                            self?.finishDownload(download)
                        }
                    default:
                        break
                    }
                }
                sink.store(in: &cancellables)
            }
        }
    }
    
    public func finishDownload(_ download: Downloadable) {
        do {
            try FileManager.default.createDirectory(at: download.localDestination.deletingLastPathComponent(), withIntermediateDirectories: true)
            try download.moveToDestination()
            try download.decompressIfNeeded()
            download.isFinishedProcessing = true
            Task { @MainActor [weak self] in
                self?.failedDownloads.remove(download)
                self?.activeDownloads.remove(download)
                self?.finishedDownloads.insert(download)
            }
        } catch {
            Task { @MainActor [weak self] in
                self?.failedDownloads.insert(download)
                self?.activeDownloads.remove(download)
            }
            do {
                if let tempLocation = download.tempLocation {
                    try FileManager.default.removeItem(at: tempLocation)
                }
            } catch { }
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
        finishedDownloads.remove(downloadable)
        failedDownloads.remove(downloadable)
        activeDownloads.insert(downloadable)
    }
    
    public func downloadDidBegin(_ download: BADownload) {
        guard let downloadable = assuredDownloads.downloadable(forDownload: download) else { return }
        downloadable.downloadProgress = .downloading(progress: Progress())
        finishedDownloads.remove(downloadable)
        failedDownloads.remove(downloadable)
        activeDownloads.insert(downloadable)
    }
    
    public func download(_ download: BADownload, finishedWithFileURL fileURL: URL) {
        BADownloadManager.shared.withExclusiveControl { [weak self] acquiredLock, error in
            guard acquiredLock, error == nil else { return }
            if let downloadable = self?.assuredDownloads.downloadable(forDownload: download) {
                downloadable.tempLocation = fileURL
                Task.detached { [weak self] in
                    self?.finishDownload(downloadable)
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
