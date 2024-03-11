//
//  FileCacher.swift
//  iOSLib Package
//
//  Created by Richard Aurbach on 6/14/2022.
//

import Foundation
import LRUCache

/// FileCacher
///
/// This object manages a cached set of files located in a single directory.
///
/// The file's URL is
/// 	```<cacheDirectory>/<key>.extension```
///
/// Since the file name and the access key are the same, it is possible to
/// rebuild the cache by scanning the cache directory.
open class LRUFileCache<I: Hashable & CustomStringConvertible, O: CustomStringConvertible>: ObservableObject {
	@Published public var cacheDirectory: URL
	private let cache: LRUCache<String, String>
	
    public init(namespace: String, version: Int, totalCostLimit: Int = .max, countLimit: Int = .max) {
        assert(!namespace.isEmpty, "LRUFileCache namespace must not be empty")
        
        cacheDirectory = namespace.isEmpty ? CacheDirectory.folder() : CacheDirectory.subFolder(name: namespace)
        
        // Versioning
        let versionFileURL = cacheDirectory.appendingPathComponent(".lru_cache_version")
        if (try? String(contentsOf: versionFileURL)) != String(version) {
            try? FileManager.default.removeItem(at: cacheDirectory)
        }
        try? String(version).write(to: versionFileURL, atomically: true, encoding: .utf8)
        
        cache = LRUCache(totalCostLimit: totalCostLimit, countLimit: countLimit)
        
		// Use the contents of the cache directory to initialize the LRUCache
		rebuild()
	}
	
	/// Return a URL for a file with a given key.
	///
	/// This is a utility which constructs a file URL (in the cacheDirectory) for a file
	/// with the specified key value. It does not check whether the file has been cached
	/// or whether it exists in the cache.
	private func cacheURL(forKey key: I, withExt ext: String) -> URL {
        return cacheDirectory.appendingPathComponent(key.description).appendingPathExtension(ext)
	}
    
    public func value(forKey key: I) -> O? {
        return cache.value(forKey: key.description)
    }
    
    public func setValue(_ value: O?, forKey key: I) {
        let destURL = cacheURL(forKey: key, withExt: "txt")
        if FileManager.default.fileExists(atPath: destURL.path) {
            try? FileManager.default.removeItem(at: destURL)
        }
        
        let stringValue = value?.description
        try? stringValue?.write(to: destURL, atomically: true, encoding: .utf8)
        cache.setValue(value, forKey: key.description, cost: stringValue?.count ?? 0)
        
        do {
            try deleteOrphanFiles()
        } catch {
            print(error)
        }
    }
    
    private func deleteOrphanFiles() throws {
        let fileManager = FileManager.default
        let directoryContents = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
        let existingCacheKeys = Set(cache.allKeys.map { $0.description })
        for fileURL in directoryContents {
            if fileURL.pathExtension == "txt" {
                let key = fileURL.deletingPathExtension().lastPathComponent
                if !existingCacheKeys.contains(key) {
                    try? fileManager.removeItem(at: fileURL)
                }
            }
        }
    }

	/// rebuild is called from the constructor, and assumes that the cache is (initially) empty.
	private func rebuild() {
		DispatchQueue.global().async { [weak self] in
			guard let self = self else { return }
			if let contents = try? FileManager.default.contentsOfDirectory(
                at: self.cacheDirectory,
                includingPropertiesForKeys: [],
                options:[.skipsHiddenFiles]
            ) {
				for item in contents {
                    if let key = item.deletingPathExtension().lastPathComponent, let value = try? String(contentsOf: item) {
                        cache.setValue(value, forKey: key, cost: value.count)
					}
				}
			}
		}
	}
}
