import Foundation
import LRUCache
import SwiftUtilities
// TODO: Move to levi/Boutique for moving off MainActor
import Boutique

#if DEBUG
fileprivate let debugBuildID = UUID()
#endif

/// A Boutique-powered LRU cache that persists values in SQLite.
open class LRUSQLiteCache<I: Encodable, O: Codable>: ObservableObject {
    @Published public var cacheDirectory: URL
    private let cache: LRUCache<String, Any?>
    
    /// Use Store2 from the new Boutique fork; it will be initialized asynchronously.
    private var coreStore: CoreStore<CacheEntry>?
    
    @MainActor
    private var deleteOrphansTimer: DispatchSourceTimer?
    private let debounceInterval: TimeInterval = 16
    
    private var jsonEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return encoder
    }
    
    /// Represents an entry in the cache, storing the value's data and encoding type.
    private struct CacheEntry: Codable, Equatable {
        let id: String       // The key hash
        let data: Data?      // Stored data (compressed or raw)
        let encoding: String // "raw", "lz4", "json", "json.lz4", or "nil"
    }
    
    public init(namespace: String, version: Int? = nil, totalBytesLimit: Int = .max, countLimit: Int = .max) {
        assert(!namespace.isEmpty, "LRUFileCache namespace must not be empty")
        
        let fileManager = FileManager.default
        let cacheRoot = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let cacheDirectory = cacheRoot.appendingPathComponent("LRUFileCache").appendingPathComponent(namespace)
        self.cacheDirectory = cacheDirectory
        
        cache = LRUCache(totalCostLimit: totalBytesLimit, countLimit: countLimit)
        
        let versionFileURL = cacheDirectory.appendingPathComponent("lru_cache_version.txt")
        var versionString = version.map(String.init) ?? Bundle.main.versionString
#if DEBUG
        versionString += debugBuildID.uuidString
#endif
        
        // Asynchronously initialize CoreStore without blocking init.
        Task {
            guard let coreStore = try? await CoreStore<CacheEntry>(
                storage: SQLiteStorageEngine(directory: .init(url: cacheDirectory)) ?? SQLiteStorageEngine.default(appendingPath: "LRUFileCache/\(namespace)"),
                cacheIdentifier: \.id
            ) else { return }
            
            // Compare version, clear store if needed.
            if let versionData = try? Data(contentsOf: versionFileURL),
               String(data: versionData, encoding: .utf8) != versionString {
                try await coreStore.removeAll()
            }
            try? versionString.data(using: .utf8)?.write(to: versionFileURL)
            
            self.coreStore = coreStore
            
            await self.rebuild()
        }
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
        Task {
            try? await coreStore?.removeByID(keyHash)
        }
    }
    public func removeAll() {
        cache.removeAllValues()
        Task {
            try? await coreStore?.removeAll()
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
                        encoding = "json.lz4"
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
        
        DispatchQueue.main.async {
            self.cache.setValue(value, forKey: keyHash, cost: dataToStore?.count ?? 1)
        }
        
        let entry = CacheEntry(id: keyHash, data: dataToStore, encoding: encoding)
        
        Task {
            try? await coreStore?.insert(entry)
            await self.debouncedDeleteOrphans()
        }
    }
    
    private func rebuild() async {
        let entries = await coreStore?.items ?? []
        for entry in entries {
            debugPrint("# REBUILD", entry.id)
            let keyHash = entry.id
            let decodedValue: O? = decodeValue(from: entry)
            DispatchQueue.main.async {
                let cost = entry.data?.count ?? 1
                self.cache.setValue(decodedValue, forKey: keyHash, cost: cost)
            }
        }
    }
    
    private func decodeValue(from entry: CacheEntry) -> O? {
        guard let data = entry.data else { return nil }
        switch entry.encoding {
        case "raw":
            if O.self == String.self { return String(data: data, encoding: .utf8) as? O }
            if O.self == [UInt8].self { return [UInt8](data) as? O }
            return data as? O
        case "lz4":
            do {
                let decompressed = try (data as NSData).decompressed(using: .lz4)
                if O.self == String.self {
                    return String(data: decompressed as Data, encoding: .utf8) as? O
                }
                if O.self == [UInt8].self {
                    return [UInt8](decompressed) as? O
                }
                return decompressed as? O
            } catch {
                print("Decompression error: \(error)")
                return nil
            }
        case "json.lz4":
            do {
                let decompressed = try (data as NSData).decompressed(using: .lz4)
                return try JSONDecoder().decode(O.self, from: decompressed as Data)
            } catch {
                print("Decompression error: \(error)")
                return nil
            }
        case "json":
            return try? JSONDecoder().decode(O.self, from: data)
        case "nil":
            return nil
        default:
            return nil
        }
    }
    
    @MainActor
    private func debouncedDeleteOrphans() {
        deleteOrphansTimer?.cancel()
        
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .background))
        timer.schedule(deadline: .now() + debounceInterval)
        
        timer.setEventHandler {
            Task {
                do {
                    try await self.deleteOrphans()
                } catch {
                    print("Error deleting orphans: \(error)")
                }
            }
        }
        
        deleteOrphansTimer = timer
        timer.resume()
    }
    
    private func deleteOrphans() async throws {
        let contents = await coreStore?.items.map { $0.id } ?? []
        let existing = Set(contents)
        let storedEntries = await coreStore?.items ?? []
        
        for entry in storedEntries where !existing.contains(entry.id) {
            try await coreStore?.remove(entry)
        }
    }
}
