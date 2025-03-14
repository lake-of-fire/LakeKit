import Foundation
import LRUCache
import SwiftUtilities
// TODO: Move to levi/Boutique for moving off MainActor
import Boutique

#if DEBUG
fileprivate let debugBuildID = UUID()
#endif

/// A Boutique-powered LRU cache that persists values in SQLite.
open class LRUFileCache<I: Encodable, O: Codable>: ObservableObject {
    @Published public var cacheDirectory: URL
    private let cache: LRUCache<String, Any?>
    
    /// Use Store2 from the new Boutique fork; it will be initialized asynchronously.
    private var store2: Store2<CacheEntry>?
    
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
        let encoding: String // "raw", "lzfse", "json", or "nil"
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
        
        // Asynchronously initialize Store2 without blocking init.
        Task {
            self.store2 = try? await Store2<CacheEntry>(
                storage: SQLiteStorageEngine(directory: .init(url: cacheDirectory)) ?? SQLiteStorageEngine.default(appendingPath: "LRUFileCache/\(namespace)"),
                cacheIdentifier: \.id
            )
            await self.rebuild()
        }
        
        // Compare version, clear store if needed.
        if let versionData = try? Data(contentsOf: versionFileURL),
           String(data: versionData, encoding: .utf8) != versionString {
            Task {
                try? await self.clearStore()
            }
        }
        try? versionString.data(using: .utf8)?.write(to: versionFileURL)
    }
    
    private func clearStore() async throws {
        try await store2?.asyncRemoveAll() ?? ()
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
    
    public func removeAll() {
        cache.removeAllValues()
        Task {
            try? await store2?.asyncRemoveAll()
        }
    }
    
    public func value(forKey key: I) -> O? {
        guard let keyHash = cacheKeyHash(key) else { return nil }
        if let value = cache.value(forKey: keyHash) as? O {
            return value
        }
        return nil
    }
    
    public func setValue(_ value: O?, forKey key: I) {
        guard let keyHash = cacheKeyHash(key) else { return }
        
        var dataToStore: Data?
        var encoding = ""
        
        if let value = value {
            do {
                if let uint8Array = value as? [UInt8] {
                    let rawData = Data(uint8Array)
                    if rawData.count > 200_000 {
                        dataToStore = try (rawData as NSData).compressed(using: .lzfse) as Data
                        encoding = "lzfse"
                    } else {
                        dataToStore = rawData
                        encoding = "raw"
                    }
                } else if let stringValue = value as? String {
                    if stringValue.utf16.count > 200_000 {
                        dataToStore = try (stringValue.data(using: .utf8)! as NSData)
                            .compressed(using: .lzfse) as Data
                        encoding = "lzfse"
                    } else {
                        dataToStore = stringValue.data(using: .utf8)
                        encoding = "raw"
                    }
                } else {
                    dataToStore = try jsonEncoder.encode(value)
                    encoding = "json"
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
            try? await store2?.asyncInsert(entry)
            await self.debouncedDeleteOrphans()
        }
    }
    
    private func rebuild() async {
        let entries = await store2?.items ?? []
        for entry in entries {
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
            return try? JSONDecoder().decode(O.self, from: data)
        case "lzfse":
            do {
                let decompressed = try (data as NSData).decompressed(using: .lzfse)
                if O.self == String.self {
                    return String(data: decompressed as Data, encoding: .utf8) as? O
                }
                if O.self == [UInt8].self {
                    return [UInt8](decompressed) as? O
                }
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
        let contents = await store2?.items.map { $0.id } ?? []
        let existing = Set(contents)
        let storedEntries = await store2?.items ?? []
        
        for entry in storedEntries where !existing.contains(entry.id) {
            try await store2?.asyncRemove(entry)
        }
    }
}
