import Foundation
import LRUCache
import SwiftUtilities

open class LRUFileCache<I: Encodable, O: Codable>: ObservableObject {
    @Published public var cacheDirectory: URL
    private let cache: LRUCache<UInt64, Any?>
    
    private lazy var jsonEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return encoder
    }()
    
    public init(namespace: String, version: Int, totalBytesLimit: Int = .max, countLimit: Int = .max) {
        assert(!namespace.isEmpty, "LRUFileCache namespace must not be empty")
        
        let fileManager = FileManager.default
        let cacheRoot = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheDirectory = cacheRoot.appendingPathComponent("LRUFileCache").appendingPathComponent(namespace)
        
        cache = LRUCache(totalCostLimit: totalBytesLimit, countLimit: countLimit)
        
        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        }
        
        let versionFileURL = cacheDirectory.appendingPathComponent(".lru_cache_version")
        if let versionData = try? Data(contentsOf: versionFileURL), String(data: versionData, encoding: .utf8) != "\(version)" {
            try? fileManager.removeItem(at: cacheDirectory)
            try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        }
        try? "\(version)".data(using: .utf8)?.write(to: versionFileURL)
        
        rebuild()
    }
    
    private func cacheURL(forKeyHash keyHash: UInt64) -> URL {
        return cacheDirectory.appendingPathComponent("hash-" + String(keyHash)).appendingPathExtension(O.self == String.self ? "lzfse" : "json")
    }
    
    private func cacheKeyHash(_ key: I) -> UInt64? {
        guard let data = try? jsonEncoder.encode(key) else { return nil }
        let hash = stableHash(data: data)
        return hash
    }
    
    public func value(forKey key: I) -> O? {
        guard let hash = cacheKeyHash(key) else { return nil }
        let value = cache.value(forKey: hash)
        if O.self == String.self, let value = value as? Data, let decompressedData = try? (value as NSData).decompressed(using: .lzfse) as Data {
            return String(data: decompressedData, encoding: .utf8) as? O
        }
        return value as? O
    }
    
    public func setValue(_ value: O?, forKey key: I) {
        guard let keyHash = cacheKeyHash(key) else { return }
        let url = cacheURL(forKeyHash: keyHash)
        do {
            if let value = value {
                if let stringValue = value as? String, let compressed = try? (stringValue.data(using: .utf8) as? NSData)?.compressed(using: .lzfse) as? Data {
                    try compressed.write(to: url, options: .atomic)
                    cache.setValue(compressed, forKey: keyHash, cost: compressed.count)
                } else if let encoded = try? jsonEncoder.encode(value) {
                    try encoded.write(to: url, options: .atomic)
                    cache.setValue(value, forKey: keyHash, cost: encoded.count)
                }
            } else {
                try FileManager.default.removeItem(at: url)
                cache.removeValue(forKey: keyHash)
            }
        } catch {
            print(error)
        }
        
        try? deleteOrphanFiles()
    }
    
    private func rebuild() {
        let fileManager = FileManager.default
        if let contents = try? fileManager.contentsOfDirectory(at: self.cacheDirectory, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) {
            for item in contents where item.pathExtension == "lzfse" {
                if let data = try? Data(contentsOf: item), let keyHash = UInt64(item.deletingPathExtension().lastPathComponent.dropFirst("hash-".count)) {
                    cache.setValue(data, forKey: keyHash, cost: data.count)
                }
            }
            for item in contents where item.pathExtension == "json" {
                if let data = try? Data(contentsOf: item), let decodedValue = try? JSONDecoder().decode(O.self, from: data), let keyHash = UInt64(item.deletingPathExtension().lastPathComponent.dropFirst("hash-".count)) {
                    cache.setValue(decodedValue, forKey: keyHash, cost: data.count)
                }
            }
            try? deleteOrphanFiles()
        }
    }
    
    private func deleteOrphanFiles() throws {
        let fileManager = FileManager.default
        let contents = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
        let existing = Set(cache.allKeys)
        
        let validExtensions = Set(["json", "lzfse"])
        for item in contents where validExtensions.contains(item.pathExtension) {
            guard let keyHash = UInt64(String(item.deletingPathExtension().lastPathComponent.dropFirst("hash-".count))) else {
                try fileManager.removeItem(at: item)
                continue
            }
            if !existing.contains(keyHash) {
                try fileManager.removeItem(at: item)
            }
        }
    }
}
