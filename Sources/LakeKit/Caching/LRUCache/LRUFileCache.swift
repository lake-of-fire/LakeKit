import Foundation
import LRUCache
import SwiftUtilities

@globalActor
fileprivate actor LRUFileCacheActor {
    static var shared = LRUFileCacheActor()
}

#if DEBUG
fileprivate let debugBuildID = UUID()
#endif

/// A Boutique-powered LRU cache that persists values in SQLite.
open class LRUFileCache<I: Encodable, O: Codable>: ObservableObject {
    @Published public var cacheDirectory: URL
    private let cache: LRUCache<String, Any?>
    
    @LRUFileCacheActor
    private var deleteOrphansTimer: DispatchSourceTimer?
#if DEBUG
    private let debounceInterval: TimeInterval = 4
#else
    private let debounceInterval: TimeInterval = 16
#endif
    
    private var jsonEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return encoder
    }
    
    public init(namespace: String, version: Int? = nil, totalBytesLimit: Int = .max, countLimit: Int = .max) {
        assert(!namespace.isEmpty, "LRUFileCache namespace must not be empty")
        
        let fileManager = FileManager.default
        let cacheRoot = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let cacheDirectory = cacheRoot.appendingPathComponent("LRUFileCache").appendingPathComponent(namespace)
        self.cacheDirectory = cacheDirectory
        
        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        }
        
        cache = LRUCache(totalCostLimit: totalBytesLimit, countLimit: countLimit)
        
        let versionFileURL = cacheDirectory.appendingPathComponent(".lru_cache_version.txt")
        var versionString = version.map(String.init) ?? Bundle.main.versionString
#if DEBUG
        versionString += debugBuildID.uuidString
#endif
        
        if let versionData = try? Data(contentsOf: versionFileURL) {
            if String(data: versionData, encoding: .utf8) != versionString {
                removeAll()
                try? fileManager.removeItem(at: cacheDirectory)
                try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
            }
        } else {
            try? fileManager.removeItem(at: cacheDirectory)
            try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        }
            
        try? versionString.data(using: .utf8)?.write(to: versionFileURL)
        
        rebuild()
    }
    
    private func cacheKeyHash(_ key: I) -> String? {
        guard let data = try? jsonEncoder.encode(key) else { return nil }
        let hash = stableHash(data: data)
        var hashData = withUnsafeBytes(of: hash) { Data($0) }
        while hashData.first == 0 { hashData.removeFirst() }
        
        let base64String = hashData.base64EncodedString()
        return base64String
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
    
    public func removeValue(forKey key: I) {
        guard let keyHash = cacheKeyHash(key) else { return }
        cache.removeValue(forKey: keyHash)
        let baseURL = cacheDirectory.appendingPathComponent(keyHash)
        let fileManager = FileManager.default
        if let files = try? fileManager.contentsOfDirectory(at: baseURL.deletingLastPathComponent(), includingPropertiesForKeys: nil) {
            for file in files where file.deletingPathExtension().lastPathComponent == keyHash {
                try? fileManager.removeItem(at: file)
            }
        }
    }
    public func removeAll() {
        cache.removeAllValues()
        let fileManager = FileManager.default
        if let files = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil) {
            for file in files where !file.lastPathComponent.hasPrefix(".") {
                try? fileManager.removeItem(at: file)
            }
        }
    }
    
    public func value(forKey key: I) -> O? {
        guard let keyHash = cacheKeyHash(key) else { return nil }
        if let value = cache.value(forKey: keyHash), let value = value as? O {
            return value
        }
        return nil
    }
    
    public func setValue(_ value: O?, forKey key: I) {
        //        debugPrint("# setval ", key, value.debugDescription.prefix(300))
        guard let keyHash = cacheKeyHash(key) else { return }
        
        var dataToStore: Data?
        var encoding = ""
        
        if let value = value {
            do {
                if let uint8Array = value as? [UInt8] {
                    let rawData = Data(uint8Array)
                    if rawData.count > 200_000 {
                        dataToStore = try (rawData as NSData).compressed(using: .lz4) as Data
                        encoding = "lz4"
                    } else {
                        dataToStore = rawData
                        encoding = "raw"
                    }
                } else if let stringValue = value as? String {
                    if stringValue.utf16.count > 200_000 {
                        dataToStore = try (stringValue.data(using: .utf8)! as NSData)
                            .compressed(using: .lz4) as Data
                        encoding = "lz4"
                    } else {
                        dataToStore = stringValue.data(using: .utf8)
                        encoding = "raw"
                    }
                } else if let dataValue = value as? Data {
                    if dataValue.count ?? 0 > 200_000 {
                        encoding = "lz4"
                    } else {
                        encoding = "raw"
                    }
                } else {
                    dataToStore = try jsonEncoder.encode(value)
                    if let rawData = dataToStore, rawData.count ?? 0 > 200_000 {
                        dataToStore = try (rawData as NSData).compressed(using: .lz4) as Data
                        encoding = "json-lz4"
                    } else {
                        encoding = "json"
                    }
                }
            } catch {
                print("Encoding error: \(error)")
            }
        } else {
            encoding = "nil"
        }
        
//        DispatchQueue.main.async {
        self.cache.setValue(value, forKey: keyHash, cost: dataToStore?.count ?? 1)
//        }
        
        let baseURL = cacheDirectory.appendingPathComponent(keyHash)
        let fileURL = baseURL.appendingPathExtension(encoding)
        if let data = dataToStore {
            try? data.write(to: fileURL, options: .atomic)
        } else {
            FileManager.default.createFile(atPath: fileURL.path, contents: nil, attributes: nil)
        }
        
        Task {
            await self.debouncedDeleteOrphans()
        }
    }
    
    private func rebuild() {
        let fileManager = FileManager.default
        if let contents = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) {
            for item in contents {
                let keyHash = item.deletingPathExtension().lastPathComponent
                let ext = item.pathExtension
                var value: O?
                var cost = 0
                if ext == "nil" {
                    value = nil
                } else {
                    guard var data = try? Data(contentsOf: item) else {
                        continue
                    }
                    if ext == "lz4" || ext == "json-lz4", let decompressed = try? (data as NSData).decompressed(using: .lz4) {
                        data = decompressed as Data
                    }
                    
                    if O.self == Data.self {
                        value = data as? O
                    } else if O.self == String.self {
                        if let string = String(data: data, encoding: .utf8) as? O {
                            value = string
                        }
                    } else if O.self == [UInt8].self {
                        value = [UInt8](data) as? O
                    } else if let decoded = try? JSONDecoder().decode(O.self, from: data) {
                        value = decoded
                    }
                    cost = data.count
                }
//                DispatchQueue.main.async {
                    self.cache.setValue(value, forKey: keyHash, cost: cost)
//                }
            }
            debugPrint("# FIN REBUILD", cacheDirectory, cache.allKeys)
        }
    }
    
    @LRUFileCacheActor
    private func debouncedDeleteOrphans() {
        debugPrint("# debo", cacheDirectory, cache.allKeys)
        deleteOrphansTimer?.cancel()
        
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .background))
        timer.schedule(deadline: .now() + debounceInterval)
        
        timer.setEventHandler {
            do {
                try self.deleteOrphanFiles()
            } catch {
                print("Error deleting orphans: \(error)")
            }
        }
        
        deleteOrphansTimer = timer
        timer.resume()
    }
    
    private func deleteOrphanFiles() throws {
        let fileManager = FileManager.default
        let existing = Set(cache.allKeys)
        debugPrint("# del", cacheDirectory, cache.allKeys)
        if let contents = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil) {
            for file in contents where !file.lastPathComponent.hasPrefix(".") {
                let keyHash = file.deletingPathExtension().lastPathComponent
                if !existing.contains(keyHash) {
                    try? fileManager.removeItem(at: file)
                }
            }
        }
    }
}
