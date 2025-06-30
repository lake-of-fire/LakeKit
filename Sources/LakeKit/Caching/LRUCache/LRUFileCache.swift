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

/// Large objects get stored on disk in the cache directory that Apple manages, which doesn't need LRU management.
open class LRUFileCache<I: Encodable, O: Codable>: ObservableObject {
//    @MainActor
    @Published public var cacheDirectory: URL
    private let cache: LRUCache<String, Any?>
    
    /// Maximum size (in bytes) for items kept in-memory. Larger items are disk-only.
    private let memoryThreshold = 1_048_576 // 1 MB
    
    /// Keys stored on disk but not loaded into the in-memory cache.
    private var diskOnlyKeys: Set<String> = []
    
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
        
        let versionFileURL = cacheRoot.appendingPathComponent("lru-cache-version-\(namespace).txt")
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
        
        let base64 = hashData.base64EncodedString()
        var output = [UInt8]()
        output.reserveCapacity(base64.utf8.count)
        
        for c in base64.utf8 {
            switch c {
            case UInt8(ascii: "+"): output.append(UInt8(ascii: "-"))
            case UInt8(ascii: "/"): output.append(UInt8(ascii: "_"))
            case UInt8(ascii: "="): break
            default: output.append(c)
            }
        }
        
        return String(decoding: output, as: UTF8.self)
    }
    
    public func removeValue(forKey key: I) {
        guard let keyHash = cacheKeyHash(key) else { return }
//        debugPrint("# REMOVE", key, cacheDirectory.lastPathComponent)
        cache.removeValue(forKey: keyHash)
        let baseURL = cacheDirectory.appendingPathComponent(keyHash)
        let fileManager = FileManager.default
        if let files = try? fileManager.contentsOfDirectory(at: baseURL.deletingLastPathComponent(), includingPropertiesForKeys: nil) {
            for file in files where file.deletingPathExtension().lastPathComponent == keyHash {
                try? fileManager.removeItem(at: file)
            }
        }
        diskOnlyKeys.remove(keyHash)
    }
    public func removeAll() {
//        debugPrint("# REMOVE ALL", cacheDirectory.lastPathComponent)
        cache.removeAllValues()
        let fileManager = FileManager.default
        if let files = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil) {
            for file in files where !file.lastPathComponent.hasPrefix(".") {
                try? fileManager.removeItem(at: file)
            }
        }
        diskOnlyKeys.removeAll()
    }
    
    public func hasKey(_ key: I) -> Bool {
        guard let keyHash = cacheKeyHash(key) else {
            return false
        }
        return diskOnlyKeys.contains(keyHash) || cache.hasKey(keyHash)
    }
    
    public func value(forKey key: I) -> O? {
        guard let keyHash = cacheKeyHash(key) else {
//            debugPrint("# no key hash", key, cacheDirectory.lastPathComponent)
            return nil
        }
        // 1) Try in-memory cache
        if let cached = cache.value(forKey: keyHash) as? O {
//            debugPrint("# got cache", key, cacheDirectory.lastPathComponent)
            return cached
        }
        // 2) If marked on disk, load from disk each time
        guard diskOnlyKeys.contains(keyHash) else {
//            debugPrint("# no disk", key, cacheDirectory.lastPathComponent)
            return nil
        }
        let baseURL = cacheDirectory.appendingPathComponent(keyHash)
        let exts = ["lz4", "json-lz4", "json", "raw", "nil"]
        for ext in exts {
            let fileURL = baseURL.appendingPathExtension(ext)
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                continue
            }
//            debugPrint("# got disk ext", key, fileURL.lastPathComponent, cacheDirectory.lastPathComponent)
            do {
                var data: Data?
                switch ext {
                case "nil":
                    // FIXME: Test this... must return "nil"ish
                    return nil
                case "raw":
                    data = try Data(contentsOf: fileURL)
                case "lz4":
                    let compressed = try Data(contentsOf: fileURL)
                    data = try (compressed as NSData).decompressed(using: .lz4) as Data
                case "json":
                    data = try Data(contentsOf: fileURL)
//                    return try JSONDecoder().decode(O.self, from: jsonData)
                case "json-lz4":
                    let compressed = try Data(contentsOf: fileURL)
                    data = try (compressed as NSData).decompressed(using: .lz4) as Data
//                    return try JSONDecoder().decode(O.self, from: decompressed)
                default:
                    break
                }
                guard let data else {
                    return nil
                }
                if O.self == String.self {
                    return String(data: data, encoding: .utf8) as? O
                } else if O.self == [UInt8].self {
                    return [UInt8](data) as? O
                } else if O.self == Data.self {
                    return data as? O
                } else {
                    return try JSONDecoder().decode(O.self, from: data)
                }
            } catch {
                continue
            }
        }
        return nil
    }
    
    public func setValue(_ value: O?, forKey key: I) {
//                debugPrint("# setval ", key, value.debugDescription.prefix(300))
//        debugPrint("# setval ", key, cacheDirectory.lastPathComponent)
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
        let dataSize = dataToStore?.count ?? 1
        let isLarge = dataSize > memoryThreshold
        if !isLarge {
            // small enough: cache in memory
            self.cache.setValue(value, forKey: keyHash, cost: dataSize)
            diskOnlyKeys.remove(keyHash)
        } else {
            // too large: disk-only
            diskOnlyKeys.insert(keyHash)
        }
        //        }
        
        let baseURL = cacheDirectory.appendingPathComponent(keyHash)
        let fileURL = baseURL.appendingPathExtension(encoding)
        if let data = dataToStore {
            try? data.write(to: fileURL, options: .atomic)
        } else {
            FileManager.default.createFile(atPath: fileURL.path, contents: nil, attributes: nil)
        }
    }
    
    private func rebuild() {
        diskOnlyKeys.removeAll()
        let fileManager = FileManager.default
        if let contents = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) {
            for item in contents {
                let keyHash = item.deletingPathExtension().lastPathComponent
                let ext = item.pathExtension
                // Track this file on disk
                // diskAllKeys.insert(keyHash)
                // Determine size to decide memory vs disk-only
                let attrs = try? FileManager.default.attributesOfItem(atPath: item.path)
                let fileSize = (attrs?[.size] as? NSNumber)?.intValue ?? 0
                
                var value: O?
                if fileSize <= memoryThreshold {
                    if ext == "nil" {
                        value = nil
                    } else if ext == "json" {
                        if let data = try? Data(contentsOf: item),
                           let decoded = try? JSONDecoder().decode(O.self, from: data) {
                            value = decoded
                        }
                    } else if ext == "lz4" {
                        if let compressed = try? Data(contentsOf: item),
                           let decompressed = try? (compressed as NSData).decompressed(using: .lz4),
                           let decoded = try? JSONDecoder().decode(O.self, from: decompressed as Data) {
                            value = decoded
                        }
                    } else {
                        if O.self == String.self {
                            if let data = try? Data(contentsOf: item),
                               let string = String(data: data, encoding: .utf8) as? O {
                                value = string
                            }
                        } else if O.self == [UInt8].self {
                            if let data = try? Data(contentsOf: item) {
                                value = [UInt8](data) as? O
                            }
                        } else if let data = try? Data(contentsOf: item),
                                  let decoded = try? JSONDecoder().decode(O.self, from: data) {
                            value = decoded
                        }
                    }
                    // TODO: Reuse data objects from above
                    let cost = (try? Data(contentsOf: item).count) ?? 1
                    //                    DispatchQueue.main.async {
                    self.cache.setValue(value, forKey: keyHash, cost: cost)
                    //                    }
                    diskOnlyKeys.remove(keyHash)
                } else {
                    diskOnlyKeys.insert(keyHash)
                }
            }
//            debugPrint("# FIN REBUILD", cacheDirectory, cache.allKeys)
        }
    }
    
    //    private func deleteOrphanFiles() throws {
    //        let fileManager = FileManager.default
    //        let existing = Set(cache.allKeys).union(diskOnlyKeys)
    //        debugPrint("# del", cacheDirectory, cache.allKeys)
    //        if let contents = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil) {
    //            for file in contents where !file.lastPathComponent.hasPrefix(".") {
    //                let keyHash = file.deletingPathExtension().lastPathComponent
    //                if !existing.contains(keyHash) {
    //                    try? fileManager.removeItem(at: file)
    //                    diskOnlyKeys.remove(keyHash)
    //                }
    //            }
    //        }
    //    }
}
