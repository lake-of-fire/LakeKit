import Foundation
import LRUCache
import SwiftUtilities

extension Bundle {
    var appVersionLong: String    { getInfo("CFBundleShortVersionString") }
    var appBuild: String          { getInfo("CFBundleVersion") }
    
    private func getInfo(_ str: String) -> String {
        infoDictionary?[str] as? String ?? "UNKNOWN-VERSION"
    }
}

#if DEBUG
fileprivate let debugBuildID = UUID()
#endif

open class LRUFileCache<I: Encodable, O: Codable>: ObservableObject {
    @Published public var cacheDirectory: URL
    private let cache: LRUCache<String, Any?>
    
    private let serialQueue = DispatchQueue(label: "\(Bundle.main.bundleIdentifier ?? "com.lake-of-fire").serialQueue", qos: .background)
    
    // Work item for debouncing
    private var deleteOrphansWorkItem: DispatchWorkItem?
    private let debounceInterval: TimeInterval = 6 // Debounce interval in seconds

    private var jsonEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return encoder
    }
    
    public init(namespace: String, version: Int? = nil, totalBytesLimit: Int = .max, countLimit: Int = .max) {
        assert(!namespace.isEmpty, "LRUFileCache namespace must not be empty")
        
        let fileManager = FileManager.default
        let cacheRoot = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        cacheDirectory = cacheRoot.appendingPathComponent("LRUFileCache").appendingPathComponent(namespace)
        
        cache = LRUCache(totalCostLimit: totalBytesLimit, countLimit: countLimit)
        
        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        }
        
        let versionFileURL = cacheDirectory.appendingPathComponent(".lru_cache_version")
        var versionString = ""
        if let version = version {
            versionString = String(version)
        } else {
            versionString = Bundle.main.appVersionLong + "-" + Bundle.main.appBuild
#if DEBUG
            versionString += debugBuildID.uuidString
#endif
        }

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
        // Convert UInt64 hash to Data
        var hashData = withUnsafeBytes(of: hash) { Data($0) }
        // Remove leading zeros to save space
        while hashData.first == 0 {
            hashData.removeFirst()
        }
        // Convert UInt64 hash to URL-safe Base64 encoded string
        let base64String = hashData.base64EncodedString()
        var safeBase64String = ""
        safeBase64String.reserveCapacity(base64String.utf8.count) // Reserving capacity for optimization
        for char in base64String {
            switch char {
            case "+":
                safeBase64String.append("-")
            case "/":
                safeBase64String.append("_")
            case "=":
                break // Skip padding characters
            default:
                safeBase64String.append(char)
            }
        }
        return safeBase64String
    }
    
    public func removeAll() {
        let fileManager = FileManager.default
        if let files = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil) {
            for file in files where !file.lastPathComponent.hasPrefix(".") {
                try? fileManager.removeItem(at: file)
            }
        }
    }

    public func value(forKey key: I) -> O? {
        guard let hash = cacheKeyHash(key) else { return nil }
        guard let value = cache.value(forKey: hash) else { return nil }
        
        if O.self == String.self {
            if let stringValue = value as? String {
                // If the value is already a string, return it
                return stringValue as? O
            } else if let dataValue = value as? Data {
                // If the value is data, try to decompress it and convert to a string
                if let decompressedData = try? (dataValue as NSData).decompressed(using: .lzfse),
                   let stringValue = String(data: decompressedData as Data, encoding: .utf8) as? O {
                    return stringValue
                }
            }
            // If neither a string nor decompression succeeded, return nil
            return nil
        } else {
            // For non-string types, return the value as is
            return value as? O
        }
    }
    
    public func setValue(_ value: O?, forKey key: I) {
        guard let keyHash = cacheKeyHash(key) else { return }
        let cacheDirectory = cacheDirectory
        
        serialQueue.async {
            let baseURL = cacheDirectory.appendingPathComponent(keyHash)
            var finalURL = value == nil ? baseURL.appendingPathExtension("nil") :
            O.self == String.self ? baseURL.appendingPathExtension("lzfse") :
            baseURL.appendingPathExtension("json")
            var calculatedCost = value == nil ? 0 : 1
            do {
                if let value = value {
                    var data: Data?
                    if let stringValue = value as? String {
                        let charCount = stringValue.utf8.underestimatedCount
                        calculatedCost = charCount
                        if charCount < 2000 {
                            finalURL = finalURL.deletingPathExtension().appendingPathExtension("txt")
                            // TODO: Writing small values to disk is too slow when frequent
                            //                        data = Data(stringValue.utf8)
                        } else {
                            guard let compressedData = try (stringValue.data(using: .utf8) as NSData?)?.compressed(using: .lzfse) else {
                                return
                            }
                            data = compressedData as Data
                        }
                    } else {
                        guard let encodedData = try? self.jsonEncoder.encode(value) else {
                            return
                        }
                        data = encodedData
                    }
                    if let data = data {
                        calculatedCost = data.underestimatedCount
                        try data.write(to: finalURL, options: .atomic)
                    }
                } else {
                    // For nil values, create an empty file with a .nil extension
                    // TODO: Writing small values to disk is too slow when frequent
                    // FileManager.default.createFile(atPath: finalURL.path, contents: nil)
                }
                
                let calculatedCostToSet = calculatedCost
                DispatchQueue.main.async {
                    // Set even if nil
                    self.cache.setValue(value, forKey: keyHash, cost: calculatedCostToSet)
                }
            } catch {
                print("Error during cache disk operation: \(error)")
            }
            
            self.debouncedDeleteOrphans()
        }
    }

    private func rebuild() {
        let fileManager = FileManager.default
        if let contents = try? fileManager.contentsOfDirectory(at: self.cacheDirectory, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) {
            for item in contents {
                let keyHash = String(item.deletingPathExtension().lastPathComponent)
                let fileExtension = item.pathExtension
                
                if fileExtension == "nil" {
                    // Handle .nil files if needed, e.g., by marking keys with nil values in the cache
                    self.cache.setValue(nil, forKey: keyHash, cost: 1)
                } else if fileExtension == "txt" || fileExtension == "json" {
                    if let data = try? Data(contentsOf: item) {
                        let value: O?
                        if fileExtension == "txt" {
                            value = String(data: data, encoding: .utf8) as? O
                        } else if fileExtension == "json", let decodedValue = try? JSONDecoder().decode(O.self, from: data) {
                            value = decodedValue
                        } else {
                            continue // Skip unsupported file types or handle as needed
                        }
                        if let value = value {
                            // Update the cache with the loaded value
                            DispatchQueue.main.async {
                                self.cache.setValue(value, forKey: keyHash, cost: data.count)
                            }
                        }
                    }
                } else if fileExtension == "lzfse" {
                    do {
                        let compressedData = try Data(contentsOf: item)
                        let decompressedData = try (compressedData as NSData).decompressed(using: .lzfse)
                        if let stringValue = String(data: decompressedData as Data, encoding: .utf8) as? O {
                            // Update the cache with the loaded value
                            DispatchQueue.main.async {
                                self.cache.setValue(stringValue, forKey: keyHash, cost: decompressedData.count)
                            }
                        } else {
                            continue // Skip if unable to decode as String
                        }
                    } catch {
                        // Handle any errors that occur during decompression
                        print("Error decompressing: \(error)")
                        continue
                    }
                }
            }
        }
    }

    private func debouncedDeleteOrphans() {
        // Cancel the previous work item if it has not yet executed
        deleteOrphansWorkItem?.cancel()
        
        // Create a new work item to execute the deletion
        let workItem = DispatchWorkItem { [weak self] in
            do {
                try self?.deleteOrphanFiles()
            } catch {
                print("Error deleting orphan files: \(error)")
            }
        }
        
        // Save the new work item and schedule it to run after the debounce interval
        deleteOrphansWorkItem = workItem
        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + debounceInterval, execute: workItem)
    }
    
    private func deleteOrphanFiles() throws {
        let fileManager = FileManager.default
        let contents = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
        let existing = Set(cache.allKeys)
        
        let validExtensions = Set(["json", "lzfse", "txt", "nil"])
        for item in contents where validExtensions.contains(item.pathExtension) {
            let keyHash = String(item.deletingPathExtension().lastPathComponent)
            if !existing.contains(keyHash) {
                try fileManager.removeItem(at: item)
            }
        }
    }
}
