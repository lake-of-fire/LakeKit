import Foundation
import SwiftUI
import Combine

public class Downloadable: ObservableObject, Identifiable, Hashable {
    let url: URL
    let mirrorURL: URL?
    let name: String
    let localDestination: URL

    @Published var downloadProgress: URLResourceDownloadTaskProgress = .uninitiated
    
    private var cancellables = Set<AnyCancellable>()
    
    public var id: String {
        return url.absoluteString
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    var lastDownloaded: Date? {
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
    
    func existsLocally() -> Bool {
        return FileManager.default.fileExists(atPath: localDestination.path)
    }
    
    func download() -> URLResourceDownloadTask {
        let task = URLResourceDownloadTask(session: URLSession.shared, url: url)
        task.publisher.sink(receiveCompletion: { _ in
        }, receiveValue: { [weak self] progress in
            self?.downloadProgress = progress
        }).store(in: &cancellables)
        return task
    }
}

public class DownloadController: ObservableObject {
    public static let shared = DownloadController()
    
    @Published var activeDownloads = Set<Downloadable>()
    @Published var finishedDownloads = Set<Downloadable>()
    @Published var failedDownloads = Set<Downloadable>()
    
    public var unfinishedDownloads: [Downloadable] {
        let downloads: [Downloadable] = Array(activeDownloads) + Array(failedDownloads)
        return downloads.sorted(by: { $0.name > $1.name })
    }
    
    private var observation: NSKeyValueObservation?
    private var cancellables = Set<AnyCancellable>()
}

public extension DownloadController {
    func ensureDownloaded(_ downloads: [Downloadable]) {
        for download in downloads {
            if download.existsLocally() {
                checkFileModifiedAt(download: download) { [weak self] modified, _ in
                    if modified {
                        self?.download(download)
                    } else {
                        self?.finishedDownloads.insert(download)
                    }
                }
            } else {
                self.download(download)
            }
        }
    }
}

fileprivate extension DownloadController {
    func download(_ download: Downloadable) {
        Task {
            let allTasks = await URLSession.shared.allTasks
            if allTasks.first(where: { $0.taskDescription == download.url.absoluteString }) != nil {
                // Task exists.
                return
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
                        Task.detached {
                            do {
                                try FileManager.default.moveItem(at: destinationLocation, to: download.localDestination)
                            } catch {
                                do {
                                    try FileManager.default.removeItem(at: destinationLocation)
                                } catch { }
                            }
                        }
                    default:
                        break
                    }
                }
                sink.store(in: &cancellables)
            }
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
