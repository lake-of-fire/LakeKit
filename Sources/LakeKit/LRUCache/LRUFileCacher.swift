import Foundation
import LRUCache

open class LRUFileCache<I: Hashable, O: Codable>: ObservableObject {
    @Published public var cacheDirectory: URL
    private let cache: LRUCache<Int, O>
    
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
    
    private func cacheURL(forKey key: I) -> URL {
        return cacheDirectory.appendingPathComponent("hash-" + String(key.hashValue)).appendingPathExtension("json")
    }
    
    public func value(forKey key: I) -> O? {
        return cache.value(forKey: key.hashValue)
    }
    
    public func setValue(_ value: O?, forKey key: I) {
        let url = cacheURL(forKey: key)
        if let value = value {
            if let encoded = try? JSONEncoder().encode(value) {
                do {
                    try encoded.write(to: url, options: .atomic)
                } catch {
                    print(error)
                }
                cache.setValue(value, forKey: key.hashValue, cost: encoded.count)
            }
        } else {
            try? FileManager.default.removeItem(at: url)
            cache.removeValue(forKey: key.hashValue)
        }
        
        try? deleteOrphanFiles()
    }
    
    private func rebuild() {
        DispatchQueue.global().async { [weak self] in
            guard let self = self else { return }
            let fileManager = FileManager.default
            if let contents = try? fileManager.contentsOfDirectory(at: self.cacheDirectory, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) {
                for item in contents where item.pathExtension == "json" {
                    if let data = try? Data(contentsOf: item), let decodedValue = try? JSONDecoder().decode(O.self, from: data), let key = Int(item.deletingPathExtension().lastPathComponent) {
                        self.cache.setValue(decodedValue, forKey: key, cost: data.count)
                    }
                }
            }
            
            try? deleteOrphanFiles()
        }
    }
    
    private func deleteOrphanFiles() throws {
        let fileManager = FileManager.default
        let contents = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
        let existing = Set(cache.allKeys)
        
        for item in contents where item.pathExtension == "json" {
            guard let hashValue = Int(String(item.deletingPathExtension().lastPathComponent.dropFirst("hash-".count))) else {
                try fileManager.removeItem(at: item)
                continue
            }
            if !existing.contains(hashValue) {
                try fileManager.removeItem(at: item)
            }
        }
    }
}
