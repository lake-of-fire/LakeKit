import Foundation
import LRUCache
import SwiftUtilities
import SQLiteData

#if DEBUG
fileprivate let debugBuildID = UUID()
#endif

@Table("cache")
fileprivate struct CacheEntry: Codable, Hashable, Sendable {
    @Column(primaryKey: true)
    var id: String
    var data: Data?
    var encoding: String // "raw", "lz4", "json", "json.lz4", or "nil"
}

fileprivate struct SQLiteLRUStore {
    private let pool: DatabasePool
    
    init(fileURL: URL) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        var config = Configuration()
        config.readonly = false
        config.maximumReaderCount = 8
        config.prepareDatabase { db in
            try db.execute(sql: "PRAGMA journal_mode=WAL")
            try db.execute(sql: "PRAGMA synchronous=NORMAL")
            try db.execute(sql: "PRAGMA foreign_keys=OFF")
        }
        self.pool = try DatabasePool(path: fileURL.path, configuration: config)
        try migrator.migrate(pool)
    }
    
    private var migrator: DatabaseMigrator {
        var m = DatabaseMigrator()
        m.registerMigration("v1_create_cache") { db in
            try #sql("""
                CREATE TABLE IF NOT EXISTS "cache"(
                    "id" TEXT NOT NULL PRIMARY KEY,
                    "data" BLOB,
                    "encoding" TEXT NOT NULL
                );
            """)
            .execute(db)
        }
        return m
    }
    
    var items: [CacheEntry] {
        (try? pool.read { db in try CacheEntry.fetchAll(db) }) ?? []
    }
    
    func insert(_ entry: CacheEntry) throws {
        try pool.write { db in
            try CacheEntry
                .upsert {
                    CacheEntry.Draft(
                        id: entry.id,
                        data: entry.data,
                        encoding: entry.encoding
                    )
                }
                .execute(db)
        }
    }
    
    func removeByID(_ id: String) throws {
        try pool.write { db in
            try CacheEntry
                .find(id)
                .delete()
                .execute(db)
        }
    }
    
    func remove(_ entry: CacheEntry) throws {
        try removeByID(entry.id)
    }
    
    func removeAll() throws {
        try pool.write { db in
            try #sql("DELETE FROM \"cache\"").execute(db)
        }
    }
    
    func exists(id: String) -> Bool {
        (try? pool.read { db in
            try CacheEntry
                .where { $0.id == id }
                .select(\.id)
                .fetchOne(db) != nil
        }) ?? false
    }
}

/// An SQLite-backed LRU cache that persists values in SQLite.
open class LRUSQLiteCache<I: Encodable, O: Codable>: ObservableObject {
    @Published public var cacheDirectory: URL
    private let cache: LRUCache<String, Any?>
    private let ioQueue = DispatchQueue(label: "LRUSQLiteCache.IO")
    
    private var store: SQLiteLRUStore?
    
    private var jsonEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return encoder
    }
    
    public init(namespace: String, version: Int? = nil, totalBytesLimit: Int = .max, countLimit: Int = .max) {
        assert(!namespace.isEmpty, "LRUSQLiteCache namespace must not be empty")
        
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
        
        let dbURL = cacheDirectory.appendingPathComponent("cache.sqlite")
        
        do {
            let store = try SQLiteLRUStore(fileURL: dbURL)
            if let versionData = try? Data(contentsOf: versionFileURL),
               String(data: versionData, encoding: .utf8) != versionString {
                try store.removeAll()
            }
            try? versionString.data(using: .utf8)?.write(to: versionFileURL)
            self.store = store
            self.rebuild()
        } catch {
            print("Failed to initialize SQLiteLRUStore: \(error)")
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
        ioQueue.async { [weak self] in
            try? self?.store?.removeByID(keyHash)
        }
    }
    public func removeAll() {
        cache.removeAll()
        ioQueue.async { [store] in
            try? store?.removeAll()
        }
    }
    
    public func value(forKey key: I) -> O? {
        guard let keyHash = cacheKeyHash(key) else { return nil }
        if let value = cache.value(forKey: keyHash), let value = value as? O {
            return value
        }
        return nil
    }
    
    public func containsKey(_ key: I) -> Bool {
        guard let keyHash = cacheKeyHash(key) else { return false }
        if cache.hasValue(forKey: keyHash) { return true }
        return store?.exists(id: keyHash) ?? false
    }
    
    public func setValue(_ value: O?, forKey key: I) {
        guard let keyHash = cacheKeyHash(key) else { return }
        let beforeKeys = Set(cache.allKeys)
        
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
                    let rawData = Data(stringValue.utf8)
                    if rawData.count > 200_000 {
                        dataToStore = try (rawData as NSData).compressed(using: .lz4) as Data
                        encoding = "lz4"
                    } else {
                        dataToStore = rawData
                        encoding = "raw"
                    }
                } else if let dataValue = value as? Data {
                    if dataValue.count > 200_000 {
                        dataToStore = try (dataValue as NSData).compressed(using: .lz4) as Data
                        encoding = "lz4"
                    } else {
                        dataToStore = dataValue
                        encoding = "raw"
                    }
                } else {
                    let rawData = try jsonEncoder.encode(value)
                    if rawData.count > 200_000 {
                        dataToStore = try (rawData as NSData).compressed(using: .lz4) as Data
                        encoding = "json.lz4"
                    } else {
                        dataToStore = rawData
                        encoding = "json"
                    }
                }
            } catch {
                print("Encoding error: \(error)")
            }
        } else {
            encoding = "nil"
        }
        
        self.cache.setValue(value, forKey: keyHash, cost: dataToStore?.count ?? 1)
        
        let entry = CacheEntry(id: keyHash, data: dataToStore, encoding: encoding)
        
        ioQueue.async { [weak self, store] in
            try? store?.insert(entry)
        }
        
        mirrorLRUEvictions(previousKeys: beforeKeys)
    }
    
    private func mirrorLRUEvictions(previousKeys: Set<String>) {
        let after = Set(cache.allKeys)
        let evicted = previousKeys.subtracting(after)
        guard let store = store, !evicted.isEmpty else { return }
        for id in evicted { try? store.removeByID(id) }
    }
    
    private func rebuild() {
        let entries = store?.items ?? []
        for entry in entries {
            let keyHash = entry.id
            let decodedValue: O? = decodeValue(from: entry)
            // Only populate in-memory cache when there is a value
            if let decodedValue {
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
}
